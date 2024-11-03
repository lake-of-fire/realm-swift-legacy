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

#import "LEGACYSyncTestCase.h"

#import <CommonCrypto/CommonHMAC.h>
#import <XCTest/XCTest.h>
#import <Realm/NewRealm.h>

#import "LEGACYRealm_Dynamic.h"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYRealmConfiguration_Private.h"
#import "LEGACYSyncManager_Private.hpp"
#import "LEGACYSyncConfiguration_Private.h"
#import "LEGACYUtil.hpp"
#import "LEGACYApp_Private.hpp"
#import "LEGACYChildProcessEnvironment.h"
#import "LEGACYRealmUtil.hpp"

#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/object-store/sync/sync_session.hpp>
#import <realm/object-store/sync/sync_user.hpp>

#if TARGET_OS_OSX

// Set this to 1 if you want the test ROS instance to log its debug messages to console.
#define LOG_ROS_OUTPUT 0

@interface LEGACYSyncManager ()
+ (void)_setCustomBundleID:(NSString *)customBundleID;
- (NSArray<LEGACYUser *> *)_allUsers;
@end

@interface LEGACYSyncTestCase ()
@property (nonatomic) NSTask *task;
@end

@interface LEGACYSyncSession ()
- (BOOL)waitForUploadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback;
- (BOOL)waitForDownloadCompletionOnQueue:(dispatch_queue_t)queue callback:(void(^)(NSError *))callback;
@end

@interface LEGACYUser ()
- (std::shared_ptr<realm::SyncUser>)_syncUser;
@end

@interface TestNetworkTransport : LEGACYNetworkTransport
- (void)waitForCompletion;
@end

#pragma mark AsyncOpenConnectionTimeoutTransport

@implementation AsyncOpenConnectionTimeoutTransport
- (void)sendRequestToServer:(LEGACYRequest *)request completion:(LEGACYNetworkTransportCompletionBlock)completionBlock {
    if ([request.url hasSuffix:@"location"]) {
        LEGACYResponse *r = [LEGACYResponse new];
        r.httpStatusCode = 200;
        r.body = @"{\"deployment_model\":\"GLOBAL\",\"location\":\"US-VA\",\"hostname\":\"http://localhost:5678\",\"ws_hostname\":\"ws://localhost:5678\"}";
        completionBlock(r);
    } else {
        [super sendRequestToServer:request completion:completionBlock];
    }
}
@end

static NSURL *syncDirectoryForChildProcess() {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0];
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = bundle.bundleIdentifier ?: bundle.executablePath.lastPathComponent;
    path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-child", bundleIdentifier]];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

#pragma mark LEGACYSyncTestCase

@implementation LEGACYSyncTestCase {
    LEGACYApp *_app;
}

- (NSArray *)defaultObjectTypes {
    return @[Person.self];
}

#pragma mark - Helper methods

- (LEGACYUser *)userForTest:(SEL)sel {
    return [self userForTest:sel app:self.app];
}

- (LEGACYUser *)userForTest:(SEL)sel app:(LEGACYApp *)app {
    return [self logInUserForCredentials:[self basicCredentialsWithName:NSStringFromSelector(sel)
                                                               register:self.isParent app:app]
                                     app:app];
}

- (LEGACYUser *)anonymousUser {
    return [self logInUserForCredentials:[LEGACYCredentials anonymousCredentials]];
}

- (LEGACYCredentials *)basicCredentialsWithName:(NSString *)name register:(BOOL)shouldRegister {
    return [self basicCredentialsWithName:name register:shouldRegister app:self.app];
}

- (LEGACYCredentials *)basicCredentialsWithName:(NSString *)name register:(BOOL)shouldRegister app:(LEGACYApp *)app {
    if (shouldRegister) {
        XCTestExpectation *ex = [self expectationWithDescription:@""];
        [app.emailPasswordAuth registerUserWithEmail:name password:@"password" completion:^(NSError *error) {
            XCTAssertNil(error);
            [ex fulfill];
        }];
        [self waitForExpectations:@[ex] timeout:20.0];
    }
    return [LEGACYCredentials credentialsWithEmail:name password:@"password"];
}

- (LEGACYAppConfiguration*)defaultAppConfiguration {
    auto config = [[LEGACYAppConfiguration alloc] initWithBaseURL:@"http://localhost:9090"
                                                     transport:[TestNetworkTransport new]
                                       defaultRequestTimeoutMS:60000];
    config.rootDirectory = self.clientDataRoot;
    return config;
}

- (void)addPersonsToRealm:(LEGACYRealm *)realm persons:(NSArray<Person *> *)persons {
    [realm beginWriteTransaction];
    [realm addObjects:persons];
    [realm commitWriteTransaction];
}

- (LEGACYRealmConfiguration *)configuration {
    LEGACYRealmConfiguration *configuration = [self configurationForUser:self.createUser];
    configuration.objectClasses = self.defaultObjectTypes;
    return configuration;
}

- (LEGACYRealmConfiguration *)configurationForUser:(LEGACYUser *)user {
    return [user configurationWithPartitionValue:self.name];
}

- (LEGACYRealm *)openRealm {
    return [self openRealmWithUser:self.createUser];
}

- (LEGACYRealm *)openRealmWithUser:(LEGACYUser *)user {
    auto c = [self configurationForUser:user];
    c.objectClasses = self.defaultObjectTypes;
    return [self openRealmWithConfiguration:c];
}

- (LEGACYRealm *)openRealmForPartitionValue:(nullable id<LEGACYBSON>)partitionValue user:(LEGACYUser *)user {
    auto c = [user configurationWithPartitionValue:partitionValue];
    c.objectClasses = self.defaultObjectTypes;
    return [self openRealmWithConfiguration:c];
}

- (LEGACYRealm *)openRealmForPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                    user:(LEGACYUser *)user
                         clientResetMode:(LEGACYClientResetMode)clientResetMode {
    auto c = [user configurationWithPartitionValue:partitionValue clientResetMode:clientResetMode];
    c.objectClasses = self.defaultObjectTypes;
    return [self openRealmWithConfiguration:c];
}

- (LEGACYRealm *)openRealmForPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                    user:(LEGACYUser *)user
                           encryptionKey:(nullable NSData *)encryptionKey
                              stopPolicy:(LEGACYSyncStopPolicy)stopPolicy {
    return [self openRealmForPartitionValue:partitionValue
                                       user:user
                            clientResetMode:LEGACYClientResetModeRecoverUnsyncedChanges
                              encryptionKey:encryptionKey
                                 stopPolicy:stopPolicy];
}

- (LEGACYRealm *)openRealmForPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                    user:(LEGACYUser *)user
                         clientResetMode:(LEGACYClientResetMode)clientResetMode
                           encryptionKey:(nullable NSData *)encryptionKey
                              stopPolicy:(LEGACYSyncStopPolicy)stopPolicy {
    LEGACYRealm *realm = [self immediatelyOpenRealmForPartitionValue:partitionValue
                                                             user:user
                                                  clientResetMode:clientResetMode
                                                    encryptionKey:encryptionKey
                                                       stopPolicy:stopPolicy];
    [self waitForDownloadsForRealm:realm];
    return realm;
}

- (LEGACYRealm *)openRealmWithConfiguration:(LEGACYRealmConfiguration *)configuration {
    LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:configuration error:nullptr];
    [self waitForDownloadsForRealm:realm];
    return realm;
}

- (LEGACYRealm *)asyncOpenRealmWithConfiguration:(LEGACYRealmConfiguration *)config {
    __block LEGACYRealm *r = nil;
    XCTestExpectation *ex = [self expectationWithDescription:@"Should asynchronously open a Realm"];
    [LEGACYRealm asyncOpenWithConfiguration:config
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(LEGACYRealm *realm, NSError *err) {
        XCTAssertNil(err);
        XCTAssertNotNil(realm);
        r = realm;
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    // Ensure that the block does not retain the Realm, as it may not be dealloced
    // immediately and so would extend the lifetime of the Realm an inconsistent amount
    auto realm = r;
    r = nil;
    return realm;
}

- (NSError *)asyncOpenErrorWithConfiguration:(LEGACYRealmConfiguration *)config {
    __block NSError *error = nil;
    XCTestExpectation *ex = [self expectationWithDescription:@"Should fail to asynchronously open a Realm"];
    [LEGACYRealm asyncOpenWithConfiguration:config
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(LEGACYRealm *r, NSError *err){
        XCTAssertNotNil(err);
        XCTAssertNil(r);
        error = err;
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    return error;
}

- (LEGACYRealm *)immediatelyOpenRealmForPartitionValue:(NSString *)partitionValue user:(LEGACYUser *)user {
    return [self immediatelyOpenRealmForPartitionValue:partitionValue
                                                  user:user
                                       clientResetMode:LEGACYClientResetModeRecoverUnsyncedChanges];
}

- (LEGACYRealm *)immediatelyOpenRealmForPartitionValue:(NSString *)partitionValue
                                               user:(LEGACYUser *)user
                                    clientResetMode:(LEGACYClientResetMode)clientResetMode {
    return [self immediatelyOpenRealmForPartitionValue:partitionValue
                                                  user:user
                                       clientResetMode:clientResetMode
                                         encryptionKey:nil
                                            stopPolicy:LEGACYSyncStopPolicyAfterChangesUploaded];
}

- (LEGACYRealm *)immediatelyOpenRealmForPartitionValue:(NSString *)partitionValue
                                               user:(LEGACYUser *)user
                                      encryptionKey:(NSData *)encryptionKey
                                         stopPolicy:(LEGACYSyncStopPolicy)stopPolicy {
    return [self immediatelyOpenRealmForPartitionValue:partitionValue
                                                  user:user
                                       clientResetMode:LEGACYClientResetModeRecoverUnsyncedChanges
                                         encryptionKey:encryptionKey
                                            stopPolicy:LEGACYSyncStopPolicyAfterChangesUploaded];
}

- (LEGACYRealm *)immediatelyOpenRealmForPartitionValue:(NSString *)partitionValue
                                               user:(LEGACYUser *)user
                                    clientResetMode:(LEGACYClientResetMode)clientResetMode
                                      encryptionKey:(NSData *)encryptionKey
                                         stopPolicy:(LEGACYSyncStopPolicy)stopPolicy {
    auto c = [user configurationWithPartitionValue:partitionValue clientResetMode:clientResetMode];
    c.encryptionKey = encryptionKey;
    c.objectClasses = self.defaultObjectTypes;
    LEGACYSyncConfiguration *syncConfig = c.syncConfiguration;
    syncConfig.stopPolicy = stopPolicy;
    c.syncConfiguration = syncConfig;
    return [LEGACYRealm realmWithConfiguration:c error:nil];
}

- (LEGACYUser *)createUser {
    return [self createUserForApp:self.app];
}

- (LEGACYUser *)createUserForApp:(LEGACYApp *)app {
    NSString *name = [self.name stringByAppendingFormat:@" %@", NSUUID.UUID.UUIDString];
    return [self logInUserForCredentials:[self basicCredentialsWithName:name register:YES app:app] app:app];
}

- (LEGACYUser *)logInUserForCredentials:(LEGACYCredentials *)credentials {
    return [self logInUserForCredentials:credentials app:self.app];
}

- (LEGACYUser *)logInUserForCredentials:(LEGACYCredentials *)credentials app:(LEGACYApp *)app {
    __block LEGACYUser* user;
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [app loginWithCredential:credentials completion:^(LEGACYUser *u, NSError *e) {
        XCTAssertNotNil(u);
        XCTAssertNil(e);
        user = u;
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:20.0];
    XCTAssertTrue(user.state == LEGACYUserStateLoggedIn, @"User should have been valid, but wasn't");
    return user;
}

- (void)logOutUser:(LEGACYUser *)user {
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [user logOutWithCompletion:^(NSError * error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:20.0];
    XCTAssertTrue(user.state == LEGACYUserStateLoggedOut, @"User should have been logged out, but wasn't");
}

- (NSString *)createJWTWithAppId:(NSString *)appId {
    NSDictionary *header = @{@"alg": @"HS256", @"typ": @"JWT"};
    NSDictionary *payload = @{
        @"aud": appId,
        @"sub": @"someUserId",
        @"exp": @1961896476,
        @"user_data": @{
            @"name": @"Foo Bar",
            @"occupation": @"firefighter"
        },
        @"my_metadata": @{
            @"name": @"Bar Foo",
            @"occupation": @"stock analyst"
        }
    };

    NSData *jsonHeader = [NSJSONSerialization  dataWithJSONObject:header options:0 error:nil];
    NSData *jsonPayload = [NSJSONSerialization  dataWithJSONObject:payload options:0 error:nil];

    NSString *base64EncodedHeader = [jsonHeader base64EncodedStringWithOptions:0];
    NSString *base64EncodedPayload = [jsonPayload base64EncodedStringWithOptions:0];

    // Remove padding characters.
    base64EncodedHeader = [base64EncodedHeader stringByReplacingOccurrencesOfString:@"=" withString:@""];
    base64EncodedPayload = [base64EncodedPayload stringByReplacingOccurrencesOfString:@"=" withString:@""];

    std::string jwtPayload = [[NSString stringWithFormat:@"%@.%@", base64EncodedHeader, base64EncodedPayload] UTF8String];
    std::string jwtKey = [@"My_very_confidential_secretttttt" UTF8String];

    NSString *key = @"My_very_confidential_secretttttt";
    NSString *data = @(jwtPayload.c_str());

    const char *cKey  = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [data cStringUsingEncoding:NSASCIIStringEncoding];

    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);

    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC
                                          length:sizeof(cHMAC)];
    NSString *hmac = [HMAC base64EncodedStringWithOptions:0];

    hmac = [hmac stringByReplacingOccurrencesOfString:@"=" withString:@""];
    hmac = [hmac stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    hmac = [hmac stringByReplacingOccurrencesOfString:@"/" withString:@"_"];

    return [NSString stringWithFormat:@"%@.%@", @(jwtPayload.c_str()), hmac];
}

- (LEGACYCredentials *)jwtCredentialWithAppId:(NSString *)appId {
    return [LEGACYCredentials credentialsWithJWT:[self createJWTWithAppId:appId]];
}

- (void)waitForDownloadsForRealm:(LEGACYRealm *)realm {
    [self waitForDownloadsForRealm:realm error:nil];
}

- (void)waitForUploadsForRealm:(LEGACYRealm *)realm {
    [self waitForUploadsForRealm:realm error:nil];
}

- (void)waitForUploadsForRealm:(LEGACYRealm *)realm error:(NSError **)error {
    LEGACYSyncSession *session = realm.syncSession;
    NSAssert(session, @"Cannot call with invalid Realm");
    XCTestExpectation *ex = [self expectationWithDescription:@"Wait for upload completion"];
    __block NSError *completionError;
    BOOL queued = [session waitForUploadCompletionOnQueue:dispatch_get_global_queue(0, 0)
                                                 callback:^(NSError *error) {
        completionError = error;
        [ex fulfill];
    }];
    if (!queued) {
        XCTFail(@"Upload waiter did not queue; session was invalid or errored out.");
        return;
    }
    [self waitForExpectations:@[ex] timeout:60.0];
    if (error)
        *error = completionError;
}

- (void)waitForDownloadsForRealm:(LEGACYRealm *)realm error:(NSError **)error {
    LEGACYSyncSession *session = realm.syncSession;
    NSAssert(session, @"Cannot call with invalid Realm");
    XCTestExpectation *ex = [self expectationWithDescription:@"Wait for download completion"];
    __block NSError *completionError;
    BOOL queued = [session waitForDownloadCompletionOnQueue:dispatch_get_global_queue(0, 0)
                                                   callback:^(NSError *error) {
        completionError = error;
        [ex fulfill];
    }];
    if (!queued) {
        XCTFail(@"Download waiter did not queue; session was invalid or errored out.");
        return;
    }
    [self waitForExpectations:@[ex] timeout:60.0];
    if (error) {
        *error = completionError;
    }
    [realm refresh];
}

- (void)setInvalidTokensForUser:(LEGACYUser *)user {
    auto token = self.badAccessToken.UTF8String;
    user._syncUser->log_out();
    user._syncUser->log_in(token, token);
}

- (void)writeToPartition:(NSString *)partition block:(void (^)(LEGACYRealm *))block {
    @autoreleasepool {
        LEGACYUser *user = [self createUser];
        auto c = [user configurationWithPartitionValue:partition];
        c.objectClasses = self.defaultObjectTypes;
        [self writeToConfiguration:c block:block];
    }
}

- (void)writeToConfiguration:(LEGACYRealmConfiguration *)config block:(void (^)(LEGACYRealm *))block {
    @autoreleasepool {
        LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:config error:nullptr];
        [self waitForDownloadsForRealm:realm];
        [realm beginWriteTransaction];
        block(realm);
        [realm commitWriteTransaction];
        [self waitForUploadsForRealm:realm];
    }

    // A synchronized Realm is not closed immediately when we release our last
    // reference as the sync worker thread also has to clean up, so retry deleting
    // it until we can, waiting up to one second. This typically takes a single
    // retry.
    int retryCount = 0;
    NSError *error;
    while (![LEGACYRealm deleteFilesForConfiguration:config error:&error]) {
        XCTAssertEqual(error.code, LEGACYErrorAlreadyOpen);
        if (++retryCount > 1000) {
            XCTFail(@"Waiting for Realm to be closed timed out");
            break;
        }
        usleep(1000);
    }
}

#pragma mark - XCUnitTest Lifecycle

+ (XCTestSuite *)defaultTestSuite {
    if ([RealmServer haveServer]) {
        return [super defaultTestSuite];
    }
    NSLog(@"Skipping sync tests: server is not present. Run `build.sh setup-baas` to install it.");
    return [[XCTestSuite alloc] initWithName:[super defaultTestSuite].name];
}

+ (void)setUp {
    [super setUp];
    // Wait for the server to launch
    if ([RealmServer haveServer]) {
        (void)[RealmServer shared];
    }
}

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    if (auto ids = NSProcessInfo.processInfo.environment[@"LEGACYParentAppIds"]) {
        _appIds = [ids componentsSeparatedByString:@","];   //take the one array for split the string
    }
    NSURL *clientDataRoot = self.clientDataRoot;
    [NSFileManager.defaultManager removeItemAtURL:clientDataRoot error:nil];
    NSError *error;
    [NSFileManager.defaultManager createDirectoryAtURL:clientDataRoot
                           withIntermediateDirectories:YES attributes:nil error:&error];
    XCTAssertNil(error);
}

- (void)tearDown {
    [self resetSyncManager];
    [RealmServer.shared deleteAppsAndReturnError:nil];
    [super tearDown];
}

static NSString *s_appId;
static bool s_opensApp;
+ (void)tearDown {
    if (s_appId && s_opensApp) {
        [RealmServer.shared deleteApp:s_appId error:nil];
        s_appId = nil;
        s_opensApp = false;
    }
}

- (NSString *)appId {
    if (s_appId) {
        return s_appId;
    }
    if (NSString *appId = NSProcessInfo.processInfo.environment[@"LEGACYParentAppId"]) {
        return s_appId = appId;
    }
    NSError *error;
    s_appId = [self createAppWithError:&error];
    if (error) {
        NSLog(@"Failed to create app: %@", error);
        abort();
    }
    s_opensApp = true;
    return s_appId;
}

- (NSString *)createAppWithError:(NSError **)error {
    return [RealmServer.shared createAppWithPartitionKeyType:@"string"
                                                       types:self.defaultObjectTypes
                                                  persistent:true error:error];
}

- (LEGACYApp *)app {
    if (!_app) {
        _app = [self appWithId:self.appId];
    }
    return _app;
}

- (void)resetSyncManager {
    _app = nil;
    [self resetAppCache];
}

- (void)resetAppCache {
    NSArray<LEGACYApp *> *apps = [LEGACYApp allApps];
    NSMutableArray<XCTestExpectation *> *exs = [NSMutableArray new];
    for (LEGACYApp *app : apps) @autoreleasepool {
        [app.allUsers enumerateKeysAndObjectsUsingBlock:^(NSString *, LEGACYUser *user, BOOL *) {
            XCTestExpectation *ex = [self expectationWithDescription:@"Wait for logout"];
            [exs addObject:ex];
            [user logOutWithCompletion:^(NSError *) {
                [ex fulfill];
            }];

            // Sessions are removed from the user asynchronously after a logout.
            // We need to wait for this to happen before calling resetForTesting as
            // that expects all sessions to be cleaned up first.
            if (user.allSessions.count) {
                [exs addObject:[self expectationForPredicate:[NSPredicate predicateWithFormat:@"allSessions.@count == 0"]
                                         evaluatedWithObject:user handler:nil]];
            }
        }];
    }

    if (exs.count) {
        [self waitForExpectations:exs timeout:60.0];
    }

    for (LEGACYApp *app : apps) {
        if (auto transport = LEGACYDynamicCast<TestNetworkTransport>(app.configuration.transport)) {
            [transport waitForCompletion];
        }
        [app.syncManager resetForTesting];
    }
    [LEGACYApp resetAppCache];
}

- (NSString *)badAccessToken {
    return @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJl"
    "eHAiOjE1ODE1MDc3OTYsImlhdCI6MTU4MTUwNTk5NiwiaXNzIjoiN"
    "WU0M2RkY2M2MzZlZTEwNmVhYTEyYmRjIiwic3RpdGNoX2RldklkIjo"
    "iMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwIiwic3RpdGNoX2RvbWFpbk"
    "lkIjoiNWUxNDk5MTNjOTBiNGFmMGViZTkzNTI3Iiwic3ViIjoiNWU0M2R"
    "kY2M2MzZlZTEwNmVhYTEyYmRhIiwidHlwIjoiYWNjZXNzIn0.0q3y9KpFx"
    "EnbmRwahvjWU1v9y1T1s3r2eozu93vMc3s";
}

- (void)cleanupRemoteDocuments:(LEGACYMongoCollection *)collection {
    XCTestExpectation *deleteManyExpectation = [self expectationWithDescription:@"should delete many documents"];
    [collection deleteManyDocumentsWhere:@{}
                              completion:^(NSInteger, NSError *error) {
        XCTAssertNil(error);
        [deleteManyExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (NSURL *)clientDataRoot {
    if (self.isParent) {
        return [NSURL fileURLWithPath:LEGACYDefaultDirectoryForBundleIdentifier(nil)];
    } else {
        return syncDirectoryForChildProcess();
    }
}

- (NSTask *)childTask {
    return [self childTaskWithAppIds:s_appId ? @[s_appId] : @[]];
}

- (LEGACYApp *)appWithId:(NSString *)appId {
    auto config = self.defaultAppConfiguration;
    config.appId = appId;
    LEGACYApp *app = [LEGACYApp appWithConfiguration:config];
    LEGACYSyncManager *syncManager = app.syncManager;
    syncManager.userAgent = self.name;
    LEGACYLogger.defaultLogger.level = LEGACYLogLevelWarn;
    return app;
}

- (NSString *)partitionBsonType:(id<LEGACYBSON>)bson {
    switch (bson.bsonType){
        case LEGACYBSONTypeString:
            return @"string";
        case LEGACYBSONTypeUUID:
            return @"uuid";
        case LEGACYBSONTypeInt32:
        case LEGACYBSONTypeInt64:
            return @"long";
        case LEGACYBSONTypeObjectId:
            return @"objectId";
        default:
            return @"";
    }
}

#pragma mark Flexible Sync App

- (NSString *)createFlexibleSyncAppWithError:(NSError **)error {
    NSArray *fields = @[@"age", @"breed", @"partition", @"firstName", @"boolCol", @"intCol", @"stringCol", @"dateCol", @"lastName", @"_id", @"uuidCol"];
    return [RealmServer.shared createAppWithFields:fields
                                             types:self.defaultObjectTypes
                                        persistent:true
                                             error:error];
}

- (void)populateData:(void (^)(LEGACYRealm *))block {
    LEGACYRealm *realm = [self openRealm];
    LEGACYRealmSubscribeToAll(realm);
    [realm beginWriteTransaction];
    block(realm);
    [realm commitWriteTransaction];
    [self waitForUploadsForRealm:realm];
}

- (void)writeQueryAndCompleteForRealm:(LEGACYRealm *)realm block:(void (^)(LEGACYSyncSubscriptionSet *))block {
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;
    XCTAssertNotNil(subs);

    XCTestExpectation *ex = [self expectationWithDescription:@"state changes"];
    [subs update:^{
        block(subs);
    } onComplete:^(NSError* error) {
        XCTAssertNil(error);
        [ex fulfill];
    }];
    XCTAssertNotNil(subs);
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
    [self waitForDownloadsForRealm:realm];
}

@end

@implementation TestNetworkTransport {
    dispatch_group_t _group;
}
- (instancetype)init {
    if (self = [super init]) {
        _group = dispatch_group_create();
    }
    return self;
}
- (void)sendRequestToServer:(LEGACYRequest *)request
                 completion:(LEGACYNetworkTransportCompletionBlock)completionBlock {
    dispatch_group_enter(_group);
    [super sendRequestToServer:request completion:^(LEGACYResponse *response) {
        completionBlock(response);
        dispatch_group_leave(_group);
    }];
}

- (void)waitForCompletion {
    dispatch_group_wait(_group, DISPATCH_TIME_FOREVER);
}
@end

@implementation LEGACYUser (Test)
- (LEGACYMongoCollection *)collectionForType:(Class)type app:(LEGACYApp *)app {
    return [[[self mongoClientWithServiceName:@"mongodb1"]
             databaseWithName:@"test_data"]
            collectionWithName:[NSString stringWithFormat:@"%@ %@", [type className], app.appId]];
}
@end

int64_t LEGACYGetClientFileIdent(LEGACYRealm *realm) {
    return realm::SyncSession::OnlyForTesting::get_file_ident(*realm->_realm->sync_session()).ident;
}

#endif // TARGET_OS_OSX
