////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "LEGACYSyncSession_Private.hpp"

#import "LEGACYApp.h"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYError_Private.hpp"
#import "LEGACYSyncConfiguration_Private.hpp"
#import "LEGACYUser_Private.hpp"
#import "LEGACYSyncManager_Private.hpp"
#import "LEGACYSyncUtil_Private.hpp"

#import <realm/object-store/sync/app.hpp>
#import <realm/object-store/sync/sync_session.hpp>

using namespace realm;

@interface LEGACYSyncErrorActionToken () {
@public
    std::string _originalPath;
    BOOL _isValid;
}
@end

@interface LEGACYProgressNotificationToken() {
    uint64_t _token;
    std::shared_ptr<SyncSession> _session;
}
@end

@implementation LEGACYProgressNotificationToken

- (void)suppressNextNotification {
    // No-op, but implemented in case this token is passed to
    // `-[LEGACYRealm commitWriteTransactionWithoutNotifying:]`.
}

- (bool)invalidate {
    if (_session) {
        _session->unregister_progress_notifier(_token);
        _session.reset();
        _token = 0;
        return true;
    }
    return false;
}

- (nullable instancetype)initWithTokenValue:(uint64_t)token
                                    session:(std::shared_ptr<SyncSession>)session {
    if (token == 0) {
        return nil;
    }
    if (self = [super init]) {
        _token = token;
        _session = session;
        return self;
    }
    return nil;
}

@end

@interface LEGACYSyncSession ()
@property (class, nonatomic, readonly) dispatch_queue_t notificationsQueue;
@property (atomic, readwrite) LEGACYSyncConnectionState connectionState;
@end

@implementation LEGACYSyncSession

+ (dispatch_queue_t)notificationsQueue {
    static auto queue = dispatch_queue_create("io.realm.sync.sessionsNotificationQueue", DISPATCH_QUEUE_SERIAL);
    return queue;
}

static LEGACYSyncConnectionState convertConnectionState(SyncSession::ConnectionState state) {
    switch (state) {
        case SyncSession::ConnectionState::Disconnected: return LEGACYSyncConnectionStateDisconnected;
        case SyncSession::ConnectionState::Connecting:   return LEGACYSyncConnectionStateConnecting;
        case SyncSession::ConnectionState::Connected:    return LEGACYSyncConnectionStateConnected;
    }
}

- (instancetype)initWithSyncSession:(std::shared_ptr<SyncSession> const&)session {
    if (self = [super init]) {
        _session = session;
        _connectionState = convertConnectionState(session->connection_state());
        // No need to save the token as LEGACYSyncSession always outlives the
        // underlying SyncSession
        session->register_connection_change_callback([=](auto, auto newState) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.connectionState = convertConnectionState(newState);
            });
        });
        return self;
    }
    return nil;
}

- (LEGACYSyncConfiguration *)configuration {
    if (auto session = _session.lock()) {
        return [[LEGACYSyncConfiguration alloc] initWithRawConfig:session->config() path:session->path()];
    }
    return nil;
}

- (NSURL *)realmURL {
    if (auto session = _session.lock()) {
        if (auto url = session->full_realm_url()) {
            return [NSURL URLWithString:@(url->c_str())];
        }
    }
    return nil;
}

- (LEGACYUser *)parentUser {
    if (auto session = _session.lock()) {
        if (auto app = session->user()->sync_manager()->app().lock()) {
            auto rlmApp = [LEGACYApp appWithId:@(app->config().app_id.data())];
            return [[LEGACYUser alloc] initWithUser:session->user() app:rlmApp];
        }
    }
    return nil;
}

- (LEGACYSyncSessionState)state {
    if (auto session = _session.lock()) {
        if (session->state() == SyncSession::State::Inactive) {
            return LEGACYSyncSessionStateInactive;
        }
        return LEGACYSyncSessionStateActive;
    }
    return LEGACYSyncSessionStateInvalid;
}

- (void)suspend {
    if (auto session = _session.lock()) {
        session->force_close();
    }
}

- (void)resume {
    if (auto session = _session.lock()) {
        session->revive_if_needed();
    }
}

- (void)pause {
    // NEXT-MAJOR: this is what suspend should be
    if (auto session = _session.lock()) {
        session->pause();
    }
}

- (void)unpause {
    // NEXT-MAJOR: this is what resume should be
    if (auto session = _session.lock()) {
        session->resume();
    }
}

- (void)reconnect {
    if (auto session = _session.lock()) {
        session->handle_reconnect();
    }
}

static util::UniqueFunction<void(Status)> wrapCompletion(dispatch_queue_t queue,
                                                         void (^callback)(NSError *)) {
    queue = queue ?: dispatch_get_main_queue();
    return [=](Status status) {
        NSError *error = makeError(status);
        dispatch_async(queue, ^{
            callback(error);
        });
    };
}

- (BOOL)waitForUploadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback {
    if (auto session = _session.lock()) {
        session->wait_for_upload_completion(wrapCompletion(queue, callback));
        return YES;
    }
    return NO;
}

- (BOOL)waitForDownloadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback {
    if (auto session = _session.lock()) {
        session->wait_for_download_completion(wrapCompletion(queue, callback));
        return YES;
    }
    return NO;
}

- (LEGACYProgressNotificationToken *)addProgressNotificationForDirection:(LEGACYSyncProgressDirection)direction
                                                                 mode:(LEGACYSyncProgressMode)mode
                                                                block:(LEGACYProgressNotificationBlock)block {
    if (auto session = _session.lock()) {
        dispatch_queue_t queue = LEGACYSyncSession.notificationsQueue;
        auto notifier_direction = (direction == LEGACYSyncProgressDirectionUpload
                                   ? SyncSession::ProgressDirection::upload
                                   : SyncSession::ProgressDirection::download);
        bool is_streaming = (mode == LEGACYSyncProgressModeReportIndefinitely);
        uint64_t token = session->register_progress_notifier([=](uint64_t transferred, uint64_t transferrable) {
            dispatch_async(queue, ^{
                block((NSUInteger)transferred, (NSUInteger)transferrable);
            });
        }, notifier_direction, is_streaming);
        return [[LEGACYProgressNotificationToken alloc] initWithTokenValue:token session:session];
    }
    return nil;
}

+ (void)immediatelyHandleError:(LEGACYSyncErrorActionToken *)token syncManager:(LEGACYSyncManager *)syncManager {
    if (!token->_isValid) {
        return;
    }
    token->_isValid = NO;

    syncManager.syncManager->immediately_run_file_actions(token->_originalPath);
}

+ (nullable LEGACYSyncSession *)sessionForRealm:(LEGACYRealm *)realm {
    auto& config = realm->_realm->config().sync_config;
    if (!config) {
        return nil;
    }
    if (auto session = config->user->session_for_on_disk_path(realm->_realm->config().path)) {
        return [[LEGACYSyncSession alloc] initWithSyncSession:session];
    }
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"<LEGACYSyncSession: %p> {\n"
            "\tstate = %d;\n"
            "\tconnectionState = %d;\n"
            "\trealmURL = %@;\n"
            "\tuser = %@;\n"
            "}",
            (__bridge void *)self,
            static_cast<int>(self.state),
            static_cast<int>(self.connectionState),
            self.realmURL,
            self.parentUser.identifier];
}

@end

// MARK: - Error action token

@implementation LEGACYSyncErrorActionToken

- (instancetype)initWithOriginalPath:(std::string)originalPath {
    if (self = [super init]) {
        _isValid = YES;
        _originalPath = std::move(originalPath);
        return self;
    }
    return nil;
}

@end
