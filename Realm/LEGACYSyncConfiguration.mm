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

#import "LEGACYSyncConfiguration_Private.hpp"

#import "LEGACYApp_Private.hpp"
#import "LEGACYBSON_Private.hpp"
#import "LEGACYError_Private.hpp"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYRealmConfiguration_Private.h"
#import "LEGACYRealmConfiguration_Private.hpp"
#import "LEGACYRealmUtil.hpp"
#import "LEGACYSchema_Private.hpp"
#import "LEGACYSyncManager_Private.hpp"
#import "LEGACYSyncSession_Private.hpp"
#import "LEGACYSyncUtil_Private.hpp"
#import "LEGACYUser_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/impl/realm_coordinator.hpp>
#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/object-store/sync/sync_session.hpp>
#import <realm/object-store/thread_safe_reference.hpp>
#import <realm/sync/config.hpp>
#import <realm/sync/protocol.hpp>

using namespace realm;

namespace {
using ProtocolError = realm::sync::ProtocolError;

struct CallbackSchema {
    bool dynamic;
    LEGACYSchema *customSchema;
};

struct BeforeClientResetWrapper : CallbackSchema {
    LEGACYClientResetBeforeBlock block;
    void operator()(std::shared_ptr<Realm> local) {
        @autoreleasepool {
            if (local->schema_version() != LEGACYNotVersioned) {
                block([LEGACYRealm realmWithSharedRealm:local schema:customSchema dynamic:dynamic freeze:true]);
            }
        }
    }
};

struct AfterClientResetWrapper : CallbackSchema {
    LEGACYClientResetAfterBlock block;
    void operator()(std::shared_ptr<Realm> local, ThreadSafeReference remote, bool) {
        @autoreleasepool {
            if (local->schema_version() == LEGACYNotVersioned) {
                return;
            }

            LEGACYRealm *localRealm = [LEGACYRealm realmWithSharedRealm:local
                                                           schema:customSchema
                                                          dynamic:dynamic
                                                           freeze:true];
            LEGACYRealm *remoteRealm = [LEGACYRealm realmWithSharedRealm:Realm::get_shared_realm(std::move(remote))
                                                            schema:customSchema
                                                           dynamic:dynamic
                                                            freeze:false];
            block(localRealm, remoteRealm);
        }
    }
};
} // anonymous namespace

@interface LEGACYSyncConfiguration () {
    std::unique_ptr<realm::SyncConfig> _config;
    LEGACYSyncErrorReportingBlock _manualClientResetHandler;
}

@end

@implementation LEGACYSyncConfiguration

@dynamic stopPolicy;

- (instancetype)initWithRawConfig:(realm::SyncConfig)config path:(std::string const&)path {
    if (self = [super init]) {
        _config = std::make_unique<realm::SyncConfig>(std::move(config));
        _path = path;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[LEGACYSyncConfiguration class]]) {
        return NO;
    }
    LEGACYSyncConfiguration *that = (LEGACYSyncConfiguration *)object;
    return [self.partitionValue isEqual:that.partitionValue]
        && [self.user isEqual:that.user]
        && self.stopPolicy == that.stopPolicy;
}

- (realm::SyncConfig&)rawConfiguration {
    return *_config;
}

- (LEGACYUser *)user {
    LEGACYApp *app = [LEGACYApp appWithId:@(_config->user->sync_manager()->app().lock()->config().app_id.data())];
    return [[LEGACYUser alloc] initWithUser:_config->user app:app];
}

- (LEGACYSyncStopPolicy)stopPolicy {
    return translateStopPolicy(_config->stop_policy);
}

- (void)setStopPolicy:(LEGACYSyncStopPolicy)stopPolicy {
    _config->stop_policy = translateStopPolicy(stopPolicy);
}

- (LEGACYClientResetMode)clientResetMode {
    return LEGACYClientResetMode(_config->client_resync_mode);
}

- (void)setClientResetMode:(LEGACYClientResetMode)clientResetMode {
    _config->client_resync_mode = realm::ClientResyncMode(clientResetMode);
}

- (LEGACYClientResetBeforeBlock)beforeClientReset {
    if (_config->notify_before_client_reset) {
        auto wrapper = _config->notify_before_client_reset.target<BeforeClientResetWrapper>();
        return wrapper->block;
    } else {
        return nil;
    }
}

- (void)setBeforeClientReset:(LEGACYClientResetBeforeBlock)beforeClientReset {
    if (!beforeClientReset) {
        _config->notify_before_client_reset = nullptr;
    } else if (self.clientResetMode == LEGACYClientResetModeManual) {
        @throw LEGACYException(@"LEGACYClientResetBeforeBlock reset notifications are not supported in Manual mode. Use LEGACYSyncConfiguration.manualClientResetHandler or LEGACYSyncManager.ErrorHandler");
    } else {
        _config->freeze_before_reset_realm = false;
        _config->notify_before_client_reset = BeforeClientResetWrapper{.block = beforeClientReset};
    }
}

- (LEGACYClientResetAfterBlock)afterClientReset {
    if (_config->notify_after_client_reset) {
        auto wrapper = _config->notify_after_client_reset.target<AfterClientResetWrapper>();
        return wrapper->block;
    } else {
        return nil;
    }
}

- (void)setAfterClientReset:(LEGACYClientResetAfterBlock)afterClientReset {
    if (!afterClientReset) {
        _config->notify_after_client_reset = nullptr;
    } else if (self.clientResetMode == LEGACYClientResetModeManual) {
        @throw LEGACYException(@"LEGACYClientResetAfterBlock reset notifications are not supported in Manual mode. Use LEGACYSyncConfiguration.manualClientResetHandler or LEGACYSyncManager.ErrorHandler");
    } else {
        _config->notify_after_client_reset = AfterClientResetWrapper{.block = afterClientReset};
    }
}

- (LEGACYSyncErrorReportingBlock)manualClientResetHandler {
    return _manualClientResetHandler;
}

- (void)setManualClientResetHandler:(LEGACYSyncErrorReportingBlock)manualClientReset {
    if (!manualClientReset) {
        _manualClientResetHandler = nil;
    } else if (self.clientResetMode != LEGACYClientResetModeManual) {
        @throw LEGACYException(@"A manual client reset handler can only be set with LEGACYClientResetModeManual");
    } else {
        _manualClientResetHandler = manualClientReset;
    }
    [self assignConfigErrorHandler:self.user];
}

void LEGACYSetConfigInfoForClientResetCallbacks(realm::SyncConfig& syncConfig, LEGACYRealmConfiguration *config) {
    if (syncConfig.notify_before_client_reset) {
        auto before = syncConfig.notify_before_client_reset.target<BeforeClientResetWrapper>();
        before->dynamic = config.dynamic;
        before->customSchema = config.customSchema;
    }
    if (syncConfig.notify_after_client_reset) {
        auto after = syncConfig.notify_after_client_reset.target<AfterClientResetWrapper>();
        after->dynamic = config.dynamic;
        after->customSchema = config.customSchema;
    }
}

- (id<LEGACYBSON>)partitionValue {
    if (!_config->partition_value.empty()) {
        return LEGACYConvertBsonToRLMBSON(realm::bson::parse(_config->partition_value.c_str()));
    }
    return nil;
}

- (bool)cancelAsyncOpenOnNonFatalErrors {
    return _config->cancel_waits_on_nonfatal_error;
}

- (void)setCancelAsyncOpenOnNonFatalErrors:(bool)cancelAsyncOpenOnNonFatalErrors {
    _config->cancel_waits_on_nonfatal_error = cancelAsyncOpenOnNonFatalErrors;
}

- (void)assignConfigErrorHandler:(LEGACYUser *)user {
    LEGACYSyncManager *manager = [user.app syncManager];
    __weak LEGACYSyncManager *weakManager = manager;
    LEGACYSyncErrorReportingBlock resetHandler = self.manualClientResetHandler;
    _config->error_handler = [weakManager, resetHandler](std::shared_ptr<SyncSession> errored_session, SyncError error) {
        LEGACYSyncErrorReportingBlock errorHandler;
        if (error.is_client_reset_requested()) {
            errorHandler = resetHandler;
        }
        if (!errorHandler) {
            @autoreleasepool {
                errorHandler = weakManager.errorHandler;
            }
        }
        if (!errorHandler) {
            return;
        }
        NSError *nsError = makeError(std::move(error));
        if (!nsError) {
            return;
        }
        LEGACYSyncSession *session = [[LEGACYSyncSession alloc] initWithSyncSession:errored_session];
        dispatch_async(dispatch_get_main_queue(), ^{
            // Keep the SyncSession alive until the callback completes as
            // LEGACYSyncSession only holds a weak reference
            static_cast<void>(errored_session);
            errorHandler(nsError, session);
        });
    };
};

static void setDefaults(SyncConfig& config, LEGACYUser *user) {
    config.client_resync_mode = ClientResyncMode::Recover;
    config.stop_policy = SyncSessionStopPolicy::AfterChangesUploaded;
    [user.app.syncManager populateConfig:config];
}

- (instancetype)initWithUser:(LEGACYUser *)user
              partitionValue:(nullable id<LEGACYBSON>)partitionValue {
    if (self = [super init]) {
        std::stringstream s;
        s << LEGACYConvertRLMBSONToBson(partitionValue);
        _config = std::make_unique<SyncConfig>([user _syncUser], s.str());
        _path = [user pathForPartitionValue:_config->partition_value];
        setDefaults(*_config, user);
        [self assignConfigErrorHandler:user];
    }
    return self;
}

- (instancetype)initWithUser:(LEGACYUser *)user {
    if (self = [super init]) {
        _config = std::make_unique<SyncConfig>([user _syncUser], SyncConfig::FLXSyncEnabled{});
        _path = [user pathForFlexibleSync];
        setDefaults(*_config, user);
        [self assignConfigErrorHandler:user];
    }
    return self;
}

@end
