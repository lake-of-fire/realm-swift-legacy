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

#import "LEGACYUser_Private.hpp"

#import "LEGACYAPIKeyAuth.h"
#import "LEGACYApp_Private.hpp"
#import "LEGACYBSON_Private.hpp"
#import "LEGACYCredentials_Private.hpp"
#import "LEGACYMongoClient_Private.hpp"
#import "LEGACYRealmConfiguration_Private.h"
#import "LEGACYSyncConfiguration_Private.hpp"
#import "LEGACYSyncSession_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/object-store/sync/sync_session.hpp>
#import <realm/object-store/sync/sync_user.hpp>
#import <realm/util/bson/bson.hpp>

using namespace realm;

@interface LEGACYUser () {
    std::shared_ptr<SyncUser> _user;
}
@end

@implementation LEGACYUserSubscriptionToken {
    std::shared_ptr<SyncUser> _user;
    std::optional<realm::Subscribable<SyncUser>::Token> _token;
}

- (instancetype)initWithUser:(std::shared_ptr<SyncUser>)user token:(realm::Subscribable<SyncUser>::Token&&)token {
    if (self = [super init]) {
        _user = std::move(user);
        _token = std::move(token);
    }
    return self;
}

- (void)unsubscribe {
    _token.reset();
    _user.reset();
}
@end

@implementation LEGACYUser

#pragma mark - API

- (instancetype)initWithUser:(std::shared_ptr<SyncUser>)user
                         app:(LEGACYApp *)app {
    if (self = [super init]) {
        _user = user;
        _app = app;
        return self;
    }
    return nil;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[LEGACYUser class]]) {
        return NO;
    }
    return _user == ((LEGACYUser *)object)->_user;
}

- (LEGACYRealmConfiguration *)configurationWithPartitionValue:(nullable id<LEGACYBSON>)partitionValue {
    return [self configurationWithPartitionValue:partitionValue clientResetMode:LEGACYClientResetModeRecoverUnsyncedChanges];
}

- (LEGACYRealmConfiguration *)configurationWithPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                           clientResetMode:(LEGACYClientResetMode)clientResetMode {
    auto syncConfig = [[LEGACYSyncConfiguration alloc] initWithUser:self
                                                  partitionValue:partitionValue];
    syncConfig.clientResetMode = clientResetMode;
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    config.syncConfiguration = syncConfig;
    return config;
}

- (LEGACYRealmConfiguration *)configurationWithPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                           clientResetMode:(LEGACYClientResetMode)clientResetMode
                                         notifyBeforeReset:(nullable LEGACYClientResetBeforeBlock)beforeResetBlock
                                          notifyAfterReset:(nullable LEGACYClientResetAfterBlock)afterResetBlock {
    auto syncConfig = [[LEGACYSyncConfiguration alloc] initWithUser:self
                                                  partitionValue:partitionValue];
    syncConfig.clientResetMode = clientResetMode;
    syncConfig.beforeClientReset = beforeResetBlock;
    syncConfig.afterClientReset = afterResetBlock;
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    config.syncConfiguration = syncConfig;
    return config;
}

- (LEGACYRealmConfiguration *)configurationWithPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                           clientResetMode:(LEGACYClientResetMode)clientResetMode
                                  manualClientResetHandler:(nullable LEGACYSyncErrorReportingBlock)manualClientResetHandler {
    auto syncConfig = [[LEGACYSyncConfiguration alloc] initWithUser:self
                                                  partitionValue:partitionValue];
    syncConfig.clientResetMode = clientResetMode;
    syncConfig.manualClientResetHandler = manualClientResetHandler;
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    config.syncConfiguration = syncConfig;
    return config;
}

- (LEGACYRealmConfiguration *)flexibleSyncConfiguration {
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    config.syncConfiguration = [[LEGACYSyncConfiguration alloc] initWithUser:self];
    return config;
}

- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithClientResetMode:(LEGACYClientResetMode)clientResetMode
                                                      notifyBeforeReset:(nullable LEGACYClientResetBeforeBlock)beforeResetBlock
                                                       notifyAfterReset:(nullable LEGACYClientResetAfterBlock)afterResetBlock {
    auto syncConfig = [[LEGACYSyncConfiguration alloc] initWithUser:self];
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    syncConfig.clientResetMode = clientResetMode;
    syncConfig.beforeClientReset = beforeResetBlock;
    syncConfig.afterClientReset = afterResetBlock;
    config.syncConfiguration = syncConfig;
    return config;
}

- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithClientResetMode:(LEGACYClientResetMode)clientResetMode
                                               manualClientResetHandler:(nullable LEGACYSyncErrorReportingBlock)manualClientResetHandler {
    auto syncConfig = [[LEGACYSyncConfiguration alloc] initWithUser:self];
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    syncConfig.clientResetMode = clientResetMode;
    syncConfig.manualClientResetHandler = manualClientResetHandler;
    config.syncConfiguration = syncConfig;
    return config;
}

- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithInitialSubscriptions:(LEGACYFlexibleSyncInitialSubscriptionsBlock)initialSubscriptions
                                                                 rerunOnOpen:(BOOL)rerunOnOpen {
    auto syncConfig = [[LEGACYSyncConfiguration alloc] initWithUser:self];
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    config.initialSubscriptions = initialSubscriptions;
    config.rerunOnOpen = rerunOnOpen;
    config.syncConfiguration = syncConfig;
    return config;
}

- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithInitialSubscriptions:(LEGACYFlexibleSyncInitialSubscriptionsBlock)initialSubscriptions
                                                                 rerunOnOpen:(BOOL)rerunOnOpen
                                                             clientResetMode:(LEGACYClientResetMode)clientResetMode
                                                           notifyBeforeReset:(nullable LEGACYClientResetBeforeBlock)beforeResetBlock
                                                            notifyAfterReset:(nullable LEGACYClientResetAfterBlock)afterResetBlock {
    auto syncConfig = [[LEGACYSyncConfiguration alloc] initWithUser:self];
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    syncConfig.clientResetMode = clientResetMode;
    syncConfig.beforeClientReset = beforeResetBlock;
    syncConfig.afterClientReset = afterResetBlock;
    config.initialSubscriptions = initialSubscriptions;
    config.rerunOnOpen = rerunOnOpen;
    config.syncConfiguration = syncConfig;
    return config;
}

- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithInitialSubscriptions:(LEGACYFlexibleSyncInitialSubscriptionsBlock)initialSubscriptions
                                                                 rerunOnOpen:(BOOL)rerunOnOpen
                                                             clientResetMode:(LEGACYClientResetMode)clientResetMode
                                                    manualClientResetHandler:(nullable LEGACYSyncErrorReportingBlock)manualClientResetHandler {
    auto syncConfig = [[LEGACYSyncConfiguration alloc] initWithUser:self];
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    syncConfig.clientResetMode = clientResetMode;
    syncConfig.manualClientResetHandler = manualClientResetHandler;
    config.initialSubscriptions = initialSubscriptions;
    config.rerunOnOpen = rerunOnOpen;
    config.syncConfiguration = syncConfig;
    return config;
}

- (void)logOut {
    if (!_user) {
        return;
    }
    _user->log_out();
}

- (BOOL)isLoggedIn {
    return _user->is_logged_in();
}

- (void)invalidate {
    if (!_user) {
        return;
    }
    _user = nullptr;
}

- (std::string)pathForPartitionValue:(std::string const&)value {
    if (!_user) {
        return "";
    }

    SyncConfig config(_user, value);
    auto path = _user->sync_manager()->path_for_realm(config, value);
    if ([NSFileManager.defaultManager fileExistsAtPath:@(path.c_str())]) {
        return path;
    }

    // Previous versions converted the partition value to a path *twice*,
    // so if the file resulting from that exists open it instead
    NSString *encodedPartitionValue = [@(value.data())
                                       stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    NSString *overEncodedRealmName = [[NSString alloc] initWithFormat:@"%@/%@", self.identifier, encodedPartitionValue];
    auto legacyPath = _user->sync_manager()->path_for_realm(config, std::string(overEncodedRealmName.UTF8String));
    if ([NSFileManager.defaultManager fileExistsAtPath:@(legacyPath.c_str())]) {
        return legacyPath;
    }

    return path;
}

- (std::string)pathForFlexibleSync {
    if (!_user) {
        @throw LEGACYException(@"This is an exceptional state, `LEGACYUser` cannot be initialised without a reference to `SyncUser`");
    }

    SyncConfig config(_user, SyncConfig::FLXSyncEnabled{});
    return _user->sync_manager()->path_for_realm(config, realm::none);
}

- (nullable LEGACYSyncSession *)sessionForPartitionValue:(id<LEGACYBSON>)partitionValue {
    if (!_user) {
        return nil;
    }

    std::stringstream s;
    s << LEGACYConvertRLMBSONToBson(partitionValue);
    auto path = [self pathForPartitionValue:s.str()];
    if (auto session = _user->session_for_on_disk_path(path)) {
        return [[LEGACYSyncSession alloc] initWithSyncSession:session];
    }
    return nil;
}

- (NSArray<LEGACYSyncSession *> *)allSessions {
    if (!_user) {
        return @[];
    }
    NSMutableArray<LEGACYSyncSession *> *buffer = [NSMutableArray array];
    auto sessions = _user->all_sessions();
    for (auto session : sessions) {
        [buffer addObject:[[LEGACYSyncSession alloc] initWithSyncSession:std::move(session)]];
    }
    return [buffer copy];
}

- (NSString *)identifier {
    if (!_user) {
        return @"";
    }
    return @(_user->identity().c_str());
}

- (NSArray<LEGACYUserIdentity *> *)identities {
    if (!_user) {
        return @[];
    }
    NSMutableArray<LEGACYUserIdentity *> *buffer = [NSMutableArray array];
    auto identities = _user->identities();
    for (auto& identity : identities) {
        [buffer addObject: [[LEGACYUserIdentity alloc] initUserIdentityWithProviderType:@(identity.provider_type.c_str())
                                                                          identifier:@(identity.id.c_str())]];
    }

    return [buffer copy];
}

- (LEGACYUserState)state {
    if (!_user) {
        return LEGACYUserStateRemoved;
    }
    switch (_user->state()) {
        case SyncUser::State::LoggedIn:
            return LEGACYUserStateLoggedIn;
        case SyncUser::State::LoggedOut:
            return LEGACYUserStateLoggedOut;
        case SyncUser::State::Removed:
            return LEGACYUserStateRemoved;
    }
}

- (void)refreshCustomDataWithCompletion:(LEGACYUserCustomDataBlock)completion {
    _user->refresh_custom_data([completion, self](std::optional<app::AppError> error) {
        if (!error) {
            return completion([self customData], nil);
        }

        completion(nil, makeError(*error));
    });
}

- (void)linkUserWithCredentials:(LEGACYCredentials *)credentials
                     completion:(LEGACYOptionalUserBlock)completion {
    _app._realmApp->link_user(_user, credentials.appCredentials,
                   ^(std::shared_ptr<SyncUser> user, std::optional<app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }

        completion([[LEGACYUser alloc] initWithUser:user app:_app], nil);
    });
}

- (void)removeWithCompletion:(LEGACYOptionalErrorBlock)completion {
    _app._realmApp->remove_user(_user, ^(std::optional<app::AppError> error) {
        [self handleResponse:error completion:completion];
    });
}

- (void)deleteWithCompletion:(LEGACYUserOptionalErrorBlock)completion {
    _app._realmApp->delete_user(_user, ^(std::optional<app::AppError> error) {
        [self handleResponse:error completion:completion];
    });
}

- (void)logOutWithCompletion:(LEGACYOptionalErrorBlock)completion {
    _app._realmApp->log_out(_user, ^(std::optional<app::AppError> error) {
        [self handleResponse:error completion:completion];
    });
}

- (LEGACYAPIKeyAuth *)apiKeysAuth {
    return [[LEGACYAPIKeyAuth alloc] initWithApp:_app];
}

- (LEGACYMongoClient *)mongoClientWithServiceName:(NSString *)serviceName {
    return [[LEGACYMongoClient alloc] initWithUser:self serviceName:serviceName];
}

- (void)callFunctionNamed:(NSString *)name
                arguments:(NSArray<id<LEGACYBSON>> *)arguments
          completionBlock:(LEGACYCallFunctionCompletionBlock)completionBlock {
    bson::BsonArray args;

    for (id<LEGACYBSON> argument in arguments) {
        args.push_back(LEGACYConvertRLMBSONToBson(argument));
    }

    _app._realmApp->call_function(_user, name.UTF8String, args,
                                  [completionBlock](std::optional<bson::Bson>&& response,
                                                    std::optional<app::AppError> error) {
        if (error) {
            return completionBlock(nil, makeError(*error));
        }

        completionBlock(LEGACYConvertBsonToRLMBSON(*response), nil);
    });
}

- (void)handleResponse:(std::optional<realm::app::AppError>)error
            completion:(LEGACYOptionalErrorBlock)completion {
    if (error) {
        return completion(makeError(*error));
    }
    completion(nil);
}

#pragma mark - Private API

- (NSString *)refreshToken {
    if (!_user || _user->refresh_token().empty()) {
        return nil;
    }
    return @(_user->refresh_token().c_str());
}

- (NSString *)accessToken {
    if (!_user || _user->access_token().empty()) {
        return nil;
    }
    return @(_user->access_token().c_str());
}

- (NSDictionary *)customData {
    if (!_user || !_user->custom_data()) {
        return @{};
    }

    return (NSDictionary *)LEGACYConvertBsonToRLMBSON(*_user->custom_data());
}

- (LEGACYUserProfile *)profile {
    if (!_user) {
        return [LEGACYUserProfile new];
    }

    return [[LEGACYUserProfile alloc] initWithUserProfile:_user->user_profile()];
}
- (std::shared_ptr<SyncUser>)_syncUser {
    return _user;
}

- (LEGACYUserSubscriptionToken *)subscribe:(LEGACYUserNotificationBlock)block {
    return [[LEGACYUserSubscriptionToken alloc] initWithUser:_user token:_user->subscribe([block, self] (auto&) {
        block(self);
    })];
}
@end

#pragma mark - LEGACYUserIdentity

@implementation LEGACYUserIdentity

- (instancetype)initUserIdentityWithProviderType:(NSString *)providerType
                                      identifier:(NSString *)identifier {
    if (self = [super init]) {
        _providerType = providerType;
        _identifier = identifier;
    }
    return self;
}

@end

#pragma mark - LEGACYUserProfile

@interface LEGACYUserProfile () {
    SyncUserProfile _userProfile;
}
@end

static NSString* userProfileMemberToNSString(const std::optional<std::string>& member) {
    if (member == util::none) {
        return nil;
    }
    return @(member->c_str());
}

@implementation LEGACYUserProfile

using UserProfileMember = std::optional<std::string> (SyncUserProfile::*)() const;

- (instancetype)initWithUserProfile:(SyncUserProfile)userProfile {
    if (self = [super init]) {
        _userProfile = std::move(userProfile);
    }
    return self;
}

- (NSString *)name {
    return userProfileMemberToNSString(_userProfile.name());
}
- (NSString *)email {
    return userProfileMemberToNSString(_userProfile.email());
}
- (NSString *)pictureURL {
    return userProfileMemberToNSString(_userProfile.picture_url());
}
- (NSString *)firstName {
    return userProfileMemberToNSString(_userProfile.first_name());
}
- (NSString *)lastName {
    return userProfileMemberToNSString(_userProfile.last_name());;
}
- (NSString *)gender {
    return userProfileMemberToNSString(_userProfile.gender());
}
- (NSString *)birthday {
    return userProfileMemberToNSString(_userProfile.birthday());
}
- (NSString *)minAge {
    return userProfileMemberToNSString(_userProfile.min_age());
}
- (NSString *)maxAge {
    return userProfileMemberToNSString(_userProfile.max_age());
}
- (NSDictionary *)metadata {
    return (NSDictionary *)LEGACYConvertBsonToRLMBSON(_userProfile.data());
}

@end
