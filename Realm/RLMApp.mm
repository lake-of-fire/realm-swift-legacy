////////////////////////////////////////////////////////////////////////////
//
// Copyright 2020 Realm Inc.
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

#import "LEGACYApp_Private.hpp"

#import <sys/utsname.h>
#if __has_include(<UIKit/UIDevice.h>)
#import <UIKit/UIDevice.h>
#define REALM_UIDEVICE_AVAILABLE
#endif

#import "LEGACYAnalytics.hpp"
#import "LEGACYBSON_Private.hpp"
#import "LEGACYCredentials_Private.hpp"
#import "LEGACYEmailPasswordAuth.h"
#import "LEGACYLogger.h"
#import "LEGACYPushClient_Private.hpp"
#import "LEGACYSyncManager_Private.hpp"
#import "LEGACYUser_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/sync/config.hpp>

#if !defined(REALM_COCOA_VERSION)
#import "LEGACYVersion.h"
#endif

using namespace realm;

#pragma mark CocoaNetworkTransport
namespace {
    /// Internal transport struct to bridge LEGACYNetworkingTransporting to the GenericNetworkTransport.
    class CocoaNetworkTransport : public realm::app::GenericNetworkTransport {
    public:
        CocoaNetworkTransport(id<LEGACYNetworkTransport> transport) : m_transport(transport) {}

        void send_request_to_server(const app::Request& request,
                                    util::UniqueFunction<void(const app::Response&)>&& completion) override {
            // Convert the app::Request to an LEGACYRequest
            auto rlmRequest = [LEGACYRequest new];
            rlmRequest.url = @(request.url.data());
            rlmRequest.body = @(request.body.data());
            NSMutableDictionary *headers = [NSMutableDictionary new];
            for (auto&& header : request.headers) {
                headers[@(header.first.data())] = @(header.second.data());
            }
            rlmRequest.headers = headers;
            rlmRequest.method = static_cast<LEGACYHTTPMethod>(request.method);
            rlmRequest.timeout = request.timeout_ms / 1000.0;

            // Send the request through to the Cocoa level transport
            auto completion_ptr = completion.release();
            [m_transport sendRequestToServer:rlmRequest completion:^(LEGACYResponse *response) {
                util::UniqueFunction<void(const app::Response&)> completion(completion_ptr);
                std::map<std::string, std::string> bridgingHeaders;
                [response.headers enumerateKeysAndObjectsUsingBlock:[&](NSString *key, NSString *value, BOOL *) {
                    bridgingHeaders[key.UTF8String] = value.UTF8String;
                }];

                // Convert the LEGACYResponse to an app:Response and pass downstream to
                // the object store
                completion(app::Response{
                    .http_status_code = static_cast<int>(response.httpStatusCode),
                    .custom_status_code = static_cast<int>(response.customStatusCode),
                    .headers = bridgingHeaders,
                    .body = response.body ? response.body.UTF8String : ""
                });
            }];
        }

        id<LEGACYNetworkTransport> transport() const {
            return m_transport;
        }
    private:
        id<LEGACYNetworkTransport> m_transport;
    };
}

#pragma mark LEGACYAppConfiguration
@implementation LEGACYAppConfiguration {
    realm::app::App::Config _config;
    SyncClientConfig _clientConfig;
}

- (instancetype)init {
    if (self = [super init]) {
        self.enableSessionMultiplexing = true;
        self.encryptMetadata = !getenv("REALM_DISABLE_METADATA_ENCRYPTION") && !LEGACYIsRunningInPlayground();
        LEGACYNSStringToStdString(_clientConfig.base_file_path, LEGACYDefaultDirectoryForBundleIdentifier(nil));
        configureSyncConnectionParameters(_config);
    }
    return self;
}

- (instancetype)initWithBaseURL:(nullable NSString *)baseURL
                      transport:(nullable id<LEGACYNetworkTransport>)transport
                   localAppName:(nullable NSString *)localAppName
                localAppVersion:(nullable NSString *)localAppVersion {
    return [self initWithBaseURL:baseURL
                       transport:transport
                    localAppName:localAppName
                 localAppVersion:localAppVersion
         defaultRequestTimeoutMS:60000];
}

- (instancetype)initWithBaseURL:(nullable NSString *)baseURL
                      transport:(nullable id<LEGACYNetworkTransport>)transport
                   localAppName:(nullable NSString *)localAppName
                localAppVersion:(nullable NSString *)localAppVersion
        defaultRequestTimeoutMS:(NSUInteger)defaultRequestTimeoutMS {
    if (self = [self init]) {
        self.baseURL = baseURL;
        self.transport = transport;
        self.localAppName = localAppName;
        self.localAppVersion = localAppVersion;
        self.defaultRequestTimeoutMS = defaultRequestTimeoutMS;
    }
    return self;
}

- (instancetype)initWithBaseURL:(nullable NSString *)baseURL
                      transport:(nullable id<LEGACYNetworkTransport>)transport {
    return [self initWithBaseURL:baseURL
                       transport:transport
         defaultRequestTimeoutMS:60000];
}

- (instancetype)initWithBaseURL:(nullable NSString *)baseURL
                      transport:(nullable id<LEGACYNetworkTransport>)transport
        defaultRequestTimeoutMS:(NSUInteger)defaultRequestTimeoutMS {
    if (self = [self init]) {
        self.baseURL = baseURL;
        self.transport = transport;
        self.defaultRequestTimeoutMS = defaultRequestTimeoutMS;
    }
    return self;
}

static void configureSyncConnectionParameters(realm::app::App::Config& config) {
    // Anonymized BundleId
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSData *bundleIdData = [bundleId dataUsingEncoding:NSUTF8StringEncoding];
    LEGACYNSStringToStdString(config.device_info.bundle_id, LEGACYHashBase16Data(bundleIdData.bytes, bundleIdData.length));

    config.device_info.sdk = "Realm Swift";
    LEGACYNSStringToStdString(config.device_info.sdk_version, REALM_COCOA_VERSION);

    // Platform info isn't available when running via `swift test`.
    // Non-Xcode SPM builds can't build for anything but macOS, so this is
    // probably unimportant for now and we can just report "unknown"
    auto processInfo = [NSProcessInfo processInfo];
    LEGACYNSStringToStdString(config.device_info.platform_version,
                           [processInfo operatingSystemVersionString] ?: @"unknown");

    LEGACYNSStringToStdString(config.device_info.framework_version, @__clang_version__);

#ifdef REALM_UIDEVICE_AVAILABLE
    LEGACYNSStringToStdString(config.device_info.device_name, [UIDevice currentDevice].model);
#endif
    struct utsname systemInfo;
    uname(&systemInfo);
    config.device_info.device_version = systemInfo.machine;
}

- (const realm::app::App::Config&)config {
    if (!_config.transport) {
        self.transport = nil;
    }
    return _config;
}

- (const realm::SyncClientConfig&)clientConfig {
    return _clientConfig;
}

- (id)copyWithZone:(NSZone *)zone {
    LEGACYAppConfiguration *copy = [[LEGACYAppConfiguration alloc] init];
    copy->_config = _config;
    copy->_clientConfig = _clientConfig;
    return copy;
}

- (NSString *)appId {
    return LEGACYStringViewToNSString(_config.app_id);
}

- (void)setAppId:(NSString *)appId {
    if ([appId length] == 0) {
        @throw LEGACYException(@"AppId cannot be an empty string");
    }

    LEGACYNSStringToStdString(_config.app_id, appId);
}

static NSString *getOptionalString(const std::optional<std::string>& str) {
    return str ? LEGACYStringViewToNSString(*str) : nil;
}

static void setOptionalString(std::optional<std::string>& dst, NSString *src) {
    if (src.length == 0) {
        dst.reset();
    }
    else {
        dst.emplace();
        LEGACYNSStringToStdString(*dst, src);
    }
}

- (NSString *)baseURL {
    return getOptionalString(_config.base_url);
}

- (void)setBaseURL:(nullable NSString *)baseURL {
    setOptionalString(_config.base_url, baseURL);
}

- (id<LEGACYNetworkTransport>)transport {
    return static_cast<CocoaNetworkTransport&>(*_config.transport).transport();
}

- (void)setTransport:(id<LEGACYNetworkTransport>)transport {
    if (!transport) {
        transport = [LEGACYNetworkTransport new];
    }
    _config.transport = std::make_shared<CocoaNetworkTransport>(transport);
}

- (NSUInteger)defaultRequestTimeoutMS {
    return _config.default_request_timeout_ms.value_or(60000U);
}

- (void)setDefaultRequestTimeoutMS:(NSUInteger)defaultRequestTimeoutMS {
    _config.default_request_timeout_ms = (uint64_t)defaultRequestTimeoutMS;
}

- (BOOL)enableSessionMultiplexing {
    return _clientConfig.multiplex_sessions;
}

- (void)setEnableSessionMultiplexing:(BOOL)enableSessionMultiplexing {
    _clientConfig.multiplex_sessions = enableSessionMultiplexing;
}

- (BOOL)encryptMetadata {
    return _clientConfig.metadata_mode == SyncManager::MetadataMode::Encryption;
}

- (void)setEncryptMetadata:(BOOL)encryptMetadata {
    _clientConfig.metadata_mode = encryptMetadata ? SyncManager::MetadataMode::Encryption
                                                  : SyncManager::MetadataMode::NoEncryption;
}

- (NSURL *)rootDirectory {
    return [NSURL fileURLWithPath:LEGACYStringViewToNSString(_clientConfig.base_file_path)];
}

- (void)setRootDirectory:(NSURL *)rootDirectory {
    LEGACYNSStringToStdString(_clientConfig.base_file_path, rootDirectory.path);
}

- (LEGACYSyncTimeoutOptions *)syncTimeouts {
    return [[LEGACYSyncTimeoutOptions alloc] initWithOptions:_clientConfig.timeouts];
}

- (void)setSyncTimeouts:(LEGACYSyncTimeoutOptions *)syncTimeouts {
    _clientConfig.timeouts = syncTimeouts->_options;
}

@end

#pragma mark LEGACYAppSubscriptionToken

@implementation LEGACYAppSubscriptionToken {
    std::shared_ptr<app::App> _app;
    std::optional<app::App::Token> _token;
}

- (instancetype)initWithApp:(std::shared_ptr<app::App>)app token:(app::App::Token&&)token {
    if (self = [super init]) {
        _app = std::move(app);
        _token = std::move(token);
    }
    return self;
}

- (void)unsubscribe {
    _token.reset();
    _app.reset();
}
@end

#pragma mark LEGACYApp
@interface LEGACYApp() <ASAuthorizationControllerDelegate> {
    std::shared_ptr<realm::app::App> _app;
    __weak id<LEGACYASLoginDelegate> _authorizationDelegate API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0));
}

@end

@implementation LEGACYApp : NSObject

+ (void)initialize {
    [LEGACYRealm class];
    // Even though there is nothing to log when the App initialises, we want to
    // be able to log anything happening after this e.g. login/register.
    [LEGACYLogger class];
}

- (instancetype)initWithApp:(std::shared_ptr<realm::app::App>&&)app config:(LEGACYAppConfiguration *)config {
    if (self = [super init]) {
        _app = std::move(app);
        _configuration = config;
        _syncManager = [[LEGACYSyncManager alloc] initWithSyncManager:_app->sync_manager()];
    }
    return self;
}

- (instancetype)initWithConfiguration:(LEGACYAppConfiguration *)configuration {
    if (self = [super init]) {
        _app = LEGACYTranslateError([&] {
            return app::App::get_app(app::App::CacheMode::Enabled, configuration.config, configuration.clientConfig);
        });
        _configuration = configuration;
        _syncManager = [[LEGACYSyncManager alloc] initWithSyncManager:_app->sync_manager()];
    }
    return self;
}

static NSMutableDictionary *s_apps = [NSMutableDictionary new];
static std::mutex& s_appMutex = *new std::mutex();

+ (NSArray *)allApps {
    std::lock_guard lock(s_appMutex);
    return s_apps.allValues;
}

+ (void)resetAppCache {
    std::lock_guard lock(s_appMutex);
    [s_apps removeAllObjects];
    app::App::clear_cached_apps();
}

+ (instancetype)appWithConfiguration:(LEGACYAppConfiguration *)configuration {
    std::lock_guard lock(s_appMutex);
    NSString *appId = configuration.appId;
    if (LEGACYApp *app = s_apps[appId]) {
        return app;
    }
    return s_apps[appId] = [[LEGACYApp alloc] initWithConfiguration:configuration.copy];
}

+ (instancetype)appWithId:(NSString *)appId configuration:(LEGACYAppConfiguration *)configuration {
    std::lock_guard lock(s_appMutex);
    if (LEGACYApp *app = s_apps[appId]) {
        return app;
    }
    configuration = configuration.copy;
    configuration.appId = appId;
    return s_apps[appId] = [[LEGACYApp alloc] initWithConfiguration:configuration];
}

+ (instancetype)appWithId:(NSString *)appId {
    std::lock_guard lock(s_appMutex);
    if (LEGACYApp *app = s_apps[appId]) {
        return app;
    }
    auto config = [[LEGACYAppConfiguration alloc] init];
    config.appId = appId;
    return s_apps[appId] = [[LEGACYApp alloc] initWithConfiguration:config];
}

- (NSString *)appId {
    return @(_app->config().app_id.c_str());
}

- (std::shared_ptr<realm::app::App>)_realmApp {
    return _app;
}

- (NSDictionary<NSString *, LEGACYUser *> *)allUsers {
    NSMutableDictionary *buffer = [NSMutableDictionary new];
    for (auto&& user : _app->sync_manager()->all_users()) {
        NSString *identity = @(user->identity().c_str());
        buffer[identity] = [[LEGACYUser alloc] initWithUser:std::move(user) app:self];
    }
    return buffer;
}

- (LEGACYUser *)currentUser {
    if (auto user = _app->sync_manager()->get_current_user()) {
        return [[LEGACYUser alloc] initWithUser:user app:self];
    }
    return nil;
}

- (LEGACYEmailPasswordAuth *)emailPasswordAuth {
    return [[LEGACYEmailPasswordAuth alloc] initWithApp: self];
}

- (void)loginWithCredential:(LEGACYCredentials *)credentials
                 completion:(LEGACYUserCompletionBlock)completionHandler {
    auto completion = ^(std::shared_ptr<SyncUser> user, std::optional<app::AppError> error) {
        if (error) {
            return completionHandler(nil, makeError(*error));
        }

        completionHandler([[LEGACYUser alloc] initWithUser:user app:self], nil);
    };
    return LEGACYTranslateError([&] {
        return _app->log_in_with_credentials(credentials.appCredentials, completion);
    });
}

- (LEGACYUser *)switchToUser:(LEGACYUser *)syncUser {
    return LEGACYTranslateError([&] {
        return [[LEGACYUser alloc] initWithUser:_app->switch_user(syncUser._syncUser) app:self];
    });
}

- (LEGACYPushClient *)pushClientWithServiceName:(NSString *)serviceName {
    return LEGACYTranslateError([&] {
        return [[LEGACYPushClient alloc] initWithPushClient:_app->push_notification_client(serviceName.UTF8String)];
    });
}

#pragma mark - Sign In With Apple Extension

- (void)setAuthorizationDelegate:(id<LEGACYASLoginDelegate>)authorizationDelegate API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    _authorizationDelegate = authorizationDelegate;
}

- (id<LEGACYASLoginDelegate>)authorizationDelegate API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    return _authorizationDelegate;
}

- (void)setASAuthorizationControllerDelegateForController:(ASAuthorizationController *)controller API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    controller.delegate = self;
}

- (void)authorizationController:(__unused ASAuthorizationController *)controller
   didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    NSString *jwt = [[NSString alloc] initWithData:((ASAuthorizationAppleIDCredential *)authorization.credential).identityToken
                                             encoding:NSUTF8StringEncoding];
       [self loginWithCredential:[LEGACYCredentials credentialsWithAppleToken:jwt]
                      completion:^(LEGACYUser *user, NSError *error) {
           if (user) {
               [self.authorizationDelegate authenticationDidCompleteWithUser:user];
           } else {
               [self.authorizationDelegate authenticationDidFailWithError:error];
           }
       }];
}

- (void)authorizationController:(__unused ASAuthorizationController *)controller
           didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0)) {
    [self.authorizationDelegate authenticationDidFailWithError:error];
}

- (LEGACYAppSubscriptionToken *)subscribe:(LEGACYAppNotificationBlock)block {
    return [[LEGACYAppSubscriptionToken alloc] initWithApp:_app token:_app->subscribe([block, self] (auto&) {
        block(self);
    })];
}

@end
