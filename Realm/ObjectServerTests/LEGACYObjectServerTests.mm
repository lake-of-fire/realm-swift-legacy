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
#import "LEGACYUser+ObjectServerTests.h"

#if TARGET_OS_OSX

#import "LEGACYApp_Private.hpp"
#import "LEGACYBSON_Private.hpp"
#import "LEGACYCredentials.h"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYRealm+Sync.h"
#import "LEGACYRealmConfiguration_Private.hpp"
#import "LEGACYRealmUtil.hpp"
#import "LEGACYRealm_Dynamic.h"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYSchema_Private.h"
#import "LEGACYSyncConfiguration_Private.hpp"
#import "LEGACYSyncManager_Private.hpp"
#import "LEGACYUser_Private.hpp"
#import "LEGACYWatchTestUtility.h"

#import <realm/object-store/shared_realm.hpp>
#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/object-store/thread_safe_reference.hpp>
#import <realm/util/file.hpp>

#import <atomic>

#pragma mark - Helpers

@interface TimeoutProxyServer : NSObject
- (instancetype)initWithPort:(uint16_t)port targetPort:(uint16_t)targetPort;
- (void)startAndReturnError:(NSError **)error;
- (void)stop;
@property (nonatomic) double delay;
@end

@interface LEGACYObjectServerTests : LEGACYSyncTestCase
@end
@implementation LEGACYObjectServerTests

- (NSArray *)defaultObjectTypes {
    return @[
        AllTypesSyncObject.class,
        HugeSyncObject.class,
        IntPrimaryKeyObject.class,
        Person.class,
        LEGACYSetSyncObject.class,
        StringPrimaryKeyObject.class,
        UUIDPrimaryKeyObject.class,
    ];
}

#pragma mark - App Tests

static NSString *generateRandomString(int num) {
    NSMutableString *string = [NSMutableString stringWithCapacity:num];
    for (int i = 0; i < num; i++) {
        [string appendFormat:@"%c", (char)('a' + arc4random_uniform(26))];
    }
    return string;
}

#pragma mark - Authentication and Tokens

- (void)testAnonymousAuthentication {
    LEGACYUser *syncUser = self.anonymousUser;
    LEGACYUser *currentUser = [self.app currentUser];
    XCTAssert([currentUser.identifier isEqualToString:syncUser.identifier]);
    XCTAssert([currentUser.refreshToken isEqualToString:syncUser.refreshToken]);
    XCTAssert([currentUser.accessToken isEqualToString:syncUser.accessToken]);
}

- (void)testCustomTokenAuthentication {
    LEGACYUser *user = [self logInUserForCredentials:[self jwtCredentialWithAppId:self.appId]];
    XCTAssertTrue([user.profile.metadata[@"anotherName"] isEqualToString:@"Bar Foo"]);
    XCTAssertTrue([user.profile.metadata[@"name"] isEqualToString:@"Foo Bar"]);
    XCTAssertTrue([user.profile.metadata[@"occupation"] isEqualToString:@"firefighter"]);
}

- (void)testCallFunction {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should get sum of arguments from remote function"];
    [self.anonymousUser callFunctionNamed:@"sum"
                                arguments:@[@1, @2, @3, @4, @5]
                          completionBlock:^(id<LEGACYBSON> bson, NSError *error) {
        XCTAssert(!error);
        XCTAssertEqual([((NSNumber *)bson) intValue], 15);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testLogoutCurrentUser {
    LEGACYUser *user = self.anonymousUser;
    XCTestExpectation *expectation = [self expectationWithDescription:@"should log out current user"];
    [self.app.currentUser logOutWithCompletion:^(NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(user.state, LEGACYUserStateRemoved);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testLogoutSpecificUser {
    LEGACYUser *firstUser = [self createUser];
    LEGACYUser *secondUser = [self createUser];

    XCTAssertEqualObjects(self.app.currentUser.identifier, secondUser.identifier);
    // `[app currentUser]` will now be `secondUser`, so let's logout firstUser and ensure
    // the state is correct
    XCTestExpectation *expectation = [self expectationWithDescription:@"should log out current user"];
    [firstUser logOutWithCompletion:^(NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(firstUser.state, LEGACYUserStateLoggedOut);
        XCTAssertEqual(secondUser.state, LEGACYUserStateLoggedIn);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testSwitchUser {
    LEGACYUser *syncUserA = [self createUser];
    LEGACYUser *syncUserB = [self createUser];

    XCTAssertNotEqualObjects(syncUserA.identifier, syncUserB.identifier);
    XCTAssertEqualObjects(self.app.currentUser.identifier, syncUserB.identifier);

    XCTAssertEqualObjects([self.app switchToUser:syncUserA].identifier, syncUserA.identifier);
}

- (void)testRemoveUser {
    LEGACYUser *firstUser = [self createUser];
    LEGACYUser *secondUser = [self createUser];

    XCTAssert([self.app.currentUser.identifier isEqualToString:secondUser.identifier]);

    XCTestExpectation *removeUserExpectation = [self expectationWithDescription:@"should remove user"];

    [secondUser removeWithCompletion:^(NSError *error) {
        XCTAssert(!error);
        XCTAssert(self.app.allUsers.count == 1);
        XCTAssert([self.app.currentUser.identifier isEqualToString:firstUser.identifier]);
        [removeUserExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testDeleteUser {
    [self createUser];
    LEGACYUser *secondUser = [self createUser];

    XCTAssert([self.app.currentUser.identifier isEqualToString:secondUser.identifier]);

    XCTestExpectation *deleteUserExpectation = [self expectationWithDescription:@"should delete user"];

    [secondUser deleteWithCompletion:^(NSError *error) {
        XCTAssert(!error);
        XCTAssert(self.app.allUsers.count == 1);
        XCTAssertNil(self.app.currentUser);
        XCTAssertEqual(secondUser.state, LEGACYUserStateRemoved);
        [deleteUserExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testDeviceRegistration {
    LEGACYPushClient *client = [self.app pushClientWithServiceName:@"gcm"];
    auto expectation = [self expectationWithDescription:@"should register device"];
    [client registerDeviceWithToken:@"token" user:self.anonymousUser completion:^(NSError *error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];

    expectation = [self expectationWithDescription:@"should deregister device"];
    [client deregisterDeviceForUser:self.app.currentUser completion:^(NSError *error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

// FIXME: Reenable once possible underlying race condition is understood
- (void)fixme_testMultipleRegisterDevice {
    LEGACYApp *app = self.app;
    XCTestExpectation *registerExpectation = [self expectationWithDescription:@"should register device"];
    XCTestExpectation *secondRegisterExpectation = [self expectationWithDescription:@"should not throw error when attempting to register again"];

    LEGACYUser *user = self.anonymousUser;
    LEGACYPushClient *client = [app pushClientWithServiceName:@"gcm"];
    [client registerDeviceWithToken:@"token" user:user completion:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        [registerExpectation fulfill];
    }];
    [self waitForExpectations:@[registerExpectation] timeout:10.0];

    [client registerDeviceWithToken:@"token" user:user completion:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        [secondRegisterExpectation fulfill];
    }];
    [self waitForExpectations:@[secondRegisterExpectation] timeout:10.0];
}

#pragma mark - LEGACYEmailPasswordAuth

static NSString *randomEmail() {
    return [NSString stringWithFormat:@"%@@%@.com", generateRandomString(10), generateRandomString(10)];
}

- (void)testRegisterEmailAndPassword {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should register with email and password"];

    NSString *randomPassword = generateRandomString(10);
    [self.app.emailPasswordAuth registerUserWithEmail:randomEmail() password:randomPassword completion:^(NSError *error) {
        XCTAssert(!error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testConfirmUser {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try confirm user and fail"];

    [self.app.emailPasswordAuth confirmUser:randomEmail() tokenId:@"a_token" completion:^(NSError *error) {
        XCTAssertEqual(error.code, LEGACYAppErrorBadRequest);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testRetryCustomConfirmation {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try retry confirmation email and fail"];

    [self.app.emailPasswordAuth retryCustomConfirmation:@"some-email@email.com" completion:^(NSError *error) {
        XCTAssertTrue([error.userInfo[@"NSLocalizedDescription"] isEqualToString:@"cannot run confirmation for some-email@email.com: automatic confirmation is enabled"]);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testResendConfirmationEmail {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try resend confirmation email and fail"];

    [self.app.emailPasswordAuth resendConfirmationEmail:randomEmail() completion:^(NSError *error) {
        XCTAssertEqual(error.code, LEGACYAppErrorUserNotFound);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testResetPassword {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try reset password and fail"];
    [self.app.emailPasswordAuth resetPasswordTo:@"APassword123" token:@"a_token" tokenId:@"a_token_id" completion:^(NSError *error) {
        XCTAssertEqual(error.code, LEGACYAppErrorBadRequest);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testCallResetPasswordFunction {
    XCTestExpectation *expectation = [self expectationWithDescription:@"should try call reset password function and fail"];
    [self.app.emailPasswordAuth callResetPasswordFunction:@"test@mongodb.com"
                                                 password:@"aPassword123"
                                                     args:@[@{}]
                                               completion:^(NSError *error) {
        XCTAssertEqual(error.code, LEGACYAppErrorUserNotFound);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

#pragma mark - UserAPIKeyProviderClient

- (void)testUserAPIKeyProviderClientFlow {
    XCTestExpectation *registerExpectation = [self expectationWithDescription:@"should try register"];
    XCTestExpectation *loginExpectation = [self expectationWithDescription:@"should try login"];
    XCTestExpectation *createAPIKeyExpectationA = [self expectationWithDescription:@"should try create an api key"];
    XCTestExpectation *createAPIKeyExpectationB = [self expectationWithDescription:@"should try create an api key"];
    XCTestExpectation *fetchAPIKeysExpectation = [self expectationWithDescription:@"should try call fetch api keys"];
    XCTestExpectation *disableAPIKeyExpectation = [self expectationWithDescription:@"should try disable api key"];
    XCTestExpectation *enableAPIKeyExpectation = [self expectationWithDescription:@"should try enable api key"];
    XCTestExpectation *deleteAPIKeyExpectation = [self expectationWithDescription:@"should try delete api key"];

    __block LEGACYUser *syncUser;
    __block LEGACYUserAPIKey *userAPIKeyA;
    __block LEGACYUserAPIKey *userAPIKeyB;

    NSString *randomPassword = generateRandomString(10);
    NSString *email = randomEmail();
    [self.app.emailPasswordAuth registerUserWithEmail:email password:randomPassword completion:^(NSError *error) {
        XCTAssert(!error);
        [registerExpectation fulfill];
    }];

    [self waitForExpectations:@[registerExpectation] timeout:60.0];

    [self.app loginWithCredential:[LEGACYCredentials credentialsWithEmail:email password:randomPassword]
                  completion:^(LEGACYUser *user, NSError *error) {
        XCTAssert(!error);
        XCTAssert(user);
        syncUser = user;
        [loginExpectation fulfill];
    }];

    [self waitForExpectations:@[loginExpectation] timeout:60.0];

    [[syncUser apiKeysAuth] createAPIKeyWithName:@"apiKeyName1" completion:^(LEGACYUserAPIKey *userAPIKey, NSError *error) {
        XCTAssert(!error);
        XCTAssert([userAPIKey.name isEqualToString:@"apiKeyName1"]);
        XCTAssert(![userAPIKey.key isEqualToString:@"apiKeyName1"] && userAPIKey.key.length > 0);
        userAPIKeyA = userAPIKey;
        [createAPIKeyExpectationA fulfill];
    }];

    [[syncUser apiKeysAuth] createAPIKeyWithName:@"apiKeyName2" completion:^(LEGACYUserAPIKey *userAPIKey, NSError *error) {
        XCTAssert(!error);
        XCTAssert([userAPIKey.name isEqualToString:@"apiKeyName2"]);
        userAPIKeyB = userAPIKey;
        [createAPIKeyExpectationB fulfill];
    }];

    [self waitForExpectations:@[createAPIKeyExpectationA, createAPIKeyExpectationB] timeout:60.0];

    // sleep for 2 seconds as there seems to be an issue fetching the keys straight after they are created.
    [NSThread sleepForTimeInterval:2];

    [[syncUser apiKeysAuth] fetchAPIKeysWithCompletion:^(NSArray<LEGACYUserAPIKey *> *_Nonnull apiKeys, NSError *error) {
        XCTAssert(!error);
        XCTAssert(apiKeys.count == 2);
        [fetchAPIKeysExpectation fulfill];
    }];

    [self waitForExpectations:@[fetchAPIKeysExpectation] timeout:60.0];

    [[syncUser apiKeysAuth] disableAPIKey:userAPIKeyA.objectId completion:^(NSError *error) {
        XCTAssert(!error);
        [disableAPIKeyExpectation fulfill];
    }];

    [self waitForExpectations:@[disableAPIKeyExpectation] timeout:60.0];

    [[syncUser apiKeysAuth] enableAPIKey:userAPIKeyA.objectId completion:^(NSError *error) {
        XCTAssert(!error);
        [enableAPIKeyExpectation fulfill];
    }];

    [self waitForExpectations:@[enableAPIKeyExpectation] timeout:60.0];

    [[syncUser apiKeysAuth] deleteAPIKey:userAPIKeyA.objectId completion:^(NSError *error) {
        XCTAssert(!error);
        [deleteAPIKeyExpectation fulfill];
    }];

    [self waitForExpectations:@[deleteAPIKeyExpectation] timeout:60.0];
}

#pragma mark - Link user -

- (void)testLinkUser {
    XCTestExpectation *registerExpectation = [self expectationWithDescription:@"should try register"];
    XCTestExpectation *loginExpectation = [self expectationWithDescription:@"should try login"];
    XCTestExpectation *linkExpectation = [self expectationWithDescription:@"should try link and fail"];

    __block LEGACYUser *syncUser;

    NSString *email = randomEmail();
    NSString *randomPassword = generateRandomString(10);

    [self.app.emailPasswordAuth registerUserWithEmail:email password:randomPassword completion:^(NSError *error) {
        XCTAssert(!error);
        [registerExpectation fulfill];
    }];

    [self waitForExpectations:@[registerExpectation] timeout:60.0];

    [self.app loginWithCredential:[LEGACYCredentials credentialsWithEmail:email password:randomPassword]
                       completion:^(LEGACYUser *user, NSError *error) {
        XCTAssert(!error);
        XCTAssert(user);
        syncUser = user;
        [loginExpectation fulfill];
    }];

    [self waitForExpectations:@[loginExpectation] timeout:60.0];

    [syncUser linkUserWithCredentials:[LEGACYCredentials credentialsWithFacebookToken:@"a_token"]
                           completion:^(LEGACYUser *user, NSError *error) {
        XCTAssert(!user);
        XCTAssertEqual(error.code, LEGACYAppErrorInvalidSession);
        [linkExpectation fulfill];
    }];

    [self waitForExpectations:@[linkExpectation] timeout:60.0];
}

#pragma mark - Auth Credentials -

- (void)testEmailPasswordCredential {
    LEGACYCredentials *emailPasswordCredential = [LEGACYCredentials credentialsWithEmail:@"test@mongodb.com" password:@"apassword"];
    XCTAssertEqualObjects(emailPasswordCredential.provider, @"local-userpass");
}

- (void)testJWTCredential {
    LEGACYCredentials *jwtCredential = [LEGACYCredentials credentialsWithJWT:@"sometoken"];
    XCTAssertEqualObjects(jwtCredential.provider, @"custom-token");
}

- (void)testAnonymousCredential {
    LEGACYCredentials *anonymousCredential = [LEGACYCredentials anonymousCredentials];
    XCTAssertEqualObjects(anonymousCredential.provider, @"anon-user");
}

- (void)testUserAPIKeyCredential {
    LEGACYCredentials *userAPICredential = [LEGACYCredentials credentialsWithUserAPIKey:@"apikey"];
    XCTAssertEqualObjects(userAPICredential.provider, @"api-key");
}

- (void)testServerAPIKeyCredential {
    LEGACYCredentials *serverAPICredential = [LEGACYCredentials credentialsWithServerAPIKey:@"apikey"];
    XCTAssertEqualObjects(serverAPICredential.provider, @"api-key");
}

- (void)testFacebookCredential {
    LEGACYCredentials *facebookCredential = [LEGACYCredentials credentialsWithFacebookToken:@"facebook token"];
    XCTAssertEqualObjects(facebookCredential.provider, @"oauth2-facebook");
}

- (void)testGoogleCredential {
    LEGACYCredentials *googleCredential = [LEGACYCredentials credentialsWithGoogleAuthCode:@"google token"];
    XCTAssertEqualObjects(googleCredential.provider, @"oauth2-google");
}

- (void)testGoogleIdCredential {
    LEGACYCredentials *googleCredential = [LEGACYCredentials credentialsWithGoogleIdToken:@"id token"];
    XCTAssertEqualObjects(googleCredential.provider, @"oauth2-google");
}

- (void)testAppleCredential {
    LEGACYCredentials *appleCredential = [LEGACYCredentials credentialsWithAppleToken:@"apple token"];
    XCTAssertEqualObjects(appleCredential.provider, @"oauth2-apple");
}

- (void)testFunctionCredential {
    NSError *error;
    LEGACYCredentials *functionCredential = [LEGACYCredentials credentialsWithFunctionPayload:@{@"dog": @{@"name": @"fido"}}];
    XCTAssertEqualObjects(functionCredential.provider, @"custom-function");
    XCTAssertEqualObjects(error, nil);
}

#pragma mark - Username Password

/// Valid email/password credentials should be able to log in a user. Using the same credentials should return the
/// same user object.
- (void)testEmailPasswordAuthentication {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name register:YES];
    LEGACYUser *firstUser = [self logInUserForCredentials:credentials];
    LEGACYUser *secondUser = [self logInUserForCredentials:credentials];
    // Two users created with the same credential should resolve to the same actual user.
    XCTAssertTrue([firstUser.identifier isEqualToString:secondUser.identifier]);
}

/// An invalid email/password credential should not be able to log in a user and a corresponding error should be generated.
- (void)testInvalidPasswordAuthentication {
    (void)[self basicCredentialsWithName:self.name register:YES];
    LEGACYCredentials *credentials = [LEGACYCredentials credentialsWithEmail:self.name
                                                              password:@"INVALID_PASSWORD"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"login should fail"];

    [self.app loginWithCredential:credentials completion:^(LEGACYUser *user, NSError *error) {
        XCTAssertNil(user);
        LEGACYValidateError(error, LEGACYAppErrorDomain, LEGACYAppErrorInvalidPassword,
                         @"invalid username/password");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// A non-existsing user should not be able to log in and a corresponding error should be generated.
- (void)testNonExistingEmailAuthentication {
    LEGACYCredentials *credentials = [LEGACYCredentials credentialsWithEmail:@"INVALID_USERNAME"
                                                              password:@"INVALID_PASSWORD"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"login should fail"];

    [self.app loginWithCredential:credentials completion:^(LEGACYUser *user, NSError *error) {
        XCTAssertNil(user);
        LEGACYValidateError(error, LEGACYAppErrorDomain, LEGACYAppErrorInvalidPassword,
                         @"invalid username/password");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

/// Registering a user with existing email should return corresponding error.
- (void)testExistingEmailRegistration {
    XCTestExpectation *expectationA = [self expectationWithDescription:@"registration should succeed"];
    [self.app.emailPasswordAuth registerUserWithEmail:self.name
                                             password:@"password"
                                           completion:^(NSError *error) {
        XCTAssertNil(error);
        [expectationA fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTestExpectation *expectationB = [self expectationWithDescription:@"registration should fail"];
    [self.app.emailPasswordAuth registerUserWithEmail:self.name
                                             password:@"password"
                                           completion:^(NSError *error) {
        LEGACYValidateError(error, LEGACYAppErrorDomain, LEGACYAppErrorAccountNameInUse, @"name already in use");
        XCTAssertNotNil(error.userInfo[LEGACYServerLogURLKey]);
        [expectationB fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testSyncErrorHandlerErrorDomain {
    LEGACYRealmConfiguration *config = self.configuration;
    XCTestExpectation *expectation = [self expectationWithDescription:@"should fail after setting bad token"];
    self.app.syncManager.errorHandler = ^(NSError *error, LEGACYSyncSession *) {
        LEGACYValidateError(error, LEGACYSyncErrorDomain, LEGACYSyncErrorClientUserError,
                         @"Unable to refresh the user access token: signature is invalid");
        [expectation fulfill];
    };

    [self setInvalidTokensForUser:config.syncConfiguration.user];
    [LEGACYRealm realmWithConfiguration:config error:nil];
    [self waitForExpectations:@[expectation] timeout:3.0];
}

#pragma mark - User Profile

- (void)testUserProfileInitialization {
    LEGACYUserProfile *profile = [[LEGACYUserProfile alloc] initWithUserProfile:realm::SyncUserProfile()];
    XCTAssertNil(profile.name);
    XCTAssertNil(profile.maxAge);
    XCTAssertNil(profile.minAge);
    XCTAssertNil(profile.birthday);
    XCTAssertNil(profile.gender);
    XCTAssertNil(profile.firstName);
    XCTAssertNil(profile.lastName);
    XCTAssertNil(profile.pictureURL);

    auto metadata = realm::bson::BsonDocument({{"some_key", "some_value"}});

    profile = [[LEGACYUserProfile alloc] initWithUserProfile:realm::SyncUserProfile(realm::bson::BsonDocument({
        {"name", "Jane"},
        {"max_age", "40"},
        {"min_age", "30"},
        {"birthday", "October 10th"},
        {"gender", "unknown"},
        {"first_name", "Jane"},
        {"last_name", "Jannson"},
        {"picture_url", "SomeURL"},
        {"other_data", metadata}
    }))];

    XCTAssert([profile.name isEqualToString:@"Jane"]);
    XCTAssert([profile.maxAge isEqualToString:@"40"]);
    XCTAssert([profile.minAge isEqualToString:@"30"]);
    XCTAssert([profile.birthday isEqualToString:@"October 10th"]);
    XCTAssert([profile.gender isEqualToString:@"unknown"]);
    XCTAssert([profile.firstName isEqualToString:@"Jane"]);
    XCTAssert([profile.lastName isEqualToString:@"Jannson"]);
    XCTAssert([profile.pictureURL isEqualToString:@"SomeURL"]);
    XCTAssertEqualObjects(profile.metadata[@"other_data"], @{@"some_key": @"some_value"});
}

#pragma mark - Basic Sync

/// It should be possible to successfully open a Realm configured for sync with a normal user.
- (void)testOpenRealmWithNormalCredentials {
    LEGACYRealm *realm = [self openRealm];
    XCTAssertTrue(realm.isEmpty);
}

/// If client B adds objects to a synced Realm, client A should see those objects.
- (void)testAddObjects {
    LEGACYRealm *realm = [self openRealm];
    NSDictionary *values = [AllTypesSyncObject values:1];
    CHECK_COUNT(0, Person, realm);
    CHECK_COUNT(0, AllTypesSyncObject, realm);

    [self writeToPartition:self.name block:^(LEGACYRealm *realm) {
        [realm addObjects:@[[Person john], [Person paul], [Person george]]];
        AllTypesSyncObject *obj = [[AllTypesSyncObject alloc] initWithValue:values];
        obj.objectCol = [Person ringo];
        [realm addObject:obj];
    }];
    [self waitForDownloadsForRealm:realm];
    CHECK_COUNT(4, Person, realm);
    CHECK_COUNT(1, AllTypesSyncObject, realm);

    AllTypesSyncObject *obj = [[AllTypesSyncObject allObjectsInRealm:realm] firstObject];
    XCTAssertEqual(obj.boolCol, [values[@"boolCol"] boolValue]);
    XCTAssertEqual(obj.cBoolCol, [values[@"cBoolCol"] boolValue]);
    XCTAssertEqual(obj.intCol, [values[@"intCol"] intValue]);
    XCTAssertEqual(obj.doubleCol, [values[@"doubleCol"] doubleValue]);
    XCTAssertEqualObjects(obj.stringCol, values[@"stringCol"]);
    XCTAssertEqualObjects(obj.binaryCol, values[@"binaryCol"]);
    XCTAssertEqualObjects(obj.decimalCol, values[@"decimalCol"]);
    XCTAssertEqual(obj.dateCol, values[@"dateCol"]);
    XCTAssertEqual(obj.longCol, [values[@"longCol"] longValue]);
    XCTAssertEqualObjects(obj.uuidCol, values[@"uuidCol"]);
    XCTAssertEqualObjects((NSNumber *)obj.anyCol, values[@"anyCol"]);
    XCTAssertEqualObjects(obj.objectCol.firstName, [Person ringo].firstName);
}

- (void)testAddObjectsWithNilPartitionValue {
    LEGACYRealm *realm = [self openRealmForPartitionValue:nil user:self.anonymousUser];

    CHECK_COUNT(0, Person, realm);
    [self writeToPartition:nil block:^(LEGACYRealm *realm) {
        [realm addObjects:@[[Person john], [Person paul], [Person george], [Person ringo]]];
    }];
    [self waitForDownloadsForRealm:realm];
    CHECK_COUNT(4, Person, realm);
}

- (void)testRountripForDistinctPrimaryKey {
    LEGACYRealm *realm = [self openRealm];

    CHECK_COUNT(0, Person, realm);
    CHECK_COUNT(0, UUIDPrimaryKeyObject, realm);
    CHECK_COUNT(0, StringPrimaryKeyObject, realm);
    CHECK_COUNT(0, IntPrimaryKeyObject, realm);

    [self writeToPartition:self.name block:^(LEGACYRealm *realm) {
        Person *person = [[Person alloc] initWithPrimaryKey:[[LEGACYObjectId alloc] initWithString:@"1234567890ab1234567890ab" error:nil]
                                                        age:5
                                                  firstName:@"Ringo"
                                                   lastName:@"Starr"];
        UUIDPrimaryKeyObject *uuidPrimaryKeyObject = [[UUIDPrimaryKeyObject alloc] initWithPrimaryKey:[[NSUUID alloc] initWithUUIDString:@"85d4fbee-6ec6-47df-bfa1-615931903d7e"]
                                                                                               strCol:@"Steve"
                                                                                               intCol:10];
        StringPrimaryKeyObject *stringPrimaryKeyObject = [[StringPrimaryKeyObject alloc] initWithPrimaryKey:@"1234567890ab1234567890aa"
                                                                                                     strCol:@"Paul"
                                                                                                     intCol:20];
        IntPrimaryKeyObject *intPrimaryKeyObject = [[IntPrimaryKeyObject alloc] initWithPrimaryKey:1234567890
                                                                                            strCol:@"Jackson"
                                                                                            intCol:30];

        [realm addObject:person];
        [realm addObject:uuidPrimaryKeyObject];
        [realm addObject:stringPrimaryKeyObject];
        [realm addObject:intPrimaryKeyObject];
    }];
    [self waitForDownloadsForRealm:realm];
    CHECK_COUNT(1, Person, realm);
    CHECK_COUNT(1, UUIDPrimaryKeyObject, realm);
    CHECK_COUNT(1, StringPrimaryKeyObject, realm);
    CHECK_COUNT(1, IntPrimaryKeyObject, realm);

    Person *person = [Person objectInRealm:realm forPrimaryKey:[[LEGACYObjectId alloc] initWithString:@"1234567890ab1234567890ab" error:nil]];
    XCTAssertEqualObjects(person.firstName, @"Ringo");
    XCTAssertEqualObjects(person.lastName, @"Starr");

    UUIDPrimaryKeyObject *uuidPrimaryKeyObject = [UUIDPrimaryKeyObject objectInRealm:realm forPrimaryKey:[[NSUUID alloc] initWithUUIDString:@"85d4fbee-6ec6-47df-bfa1-615931903d7e"]];
    XCTAssertEqualObjects(uuidPrimaryKeyObject.strCol, @"Steve");
    XCTAssertEqual(uuidPrimaryKeyObject.intCol, 10);

    StringPrimaryKeyObject *stringPrimaryKeyObject = [StringPrimaryKeyObject objectInRealm:realm forPrimaryKey:@"1234567890ab1234567890aa"];
    XCTAssertEqualObjects(stringPrimaryKeyObject.strCol, @"Paul");
    XCTAssertEqual(stringPrimaryKeyObject.intCol, 20);

    IntPrimaryKeyObject *intPrimaryKeyObject = [IntPrimaryKeyObject objectInRealm:realm forPrimaryKey:@1234567890];
    XCTAssertEqualObjects(intPrimaryKeyObject.strCol, @"Jackson");
    XCTAssertEqual(intPrimaryKeyObject.intCol, 30);
}

- (void)testAddObjectsMultipleApps {
    NSString *appId1 = [RealmServer.shared createAppWithPartitionKeyType:@"string" types:@[Person.self] persistent:false error:nil];
    NSString *appId2 = [RealmServer.shared createAppWithPartitionKeyType:@"string" types:@[Person.self] persistent:false error:nil];
    LEGACYApp *app1 = [self appWithId:appId1];
    LEGACYApp *app2 = [self appWithId:appId2];

    auto openRealm = [=](LEGACYApp *app) {
        LEGACYUser *user = [self createUserForApp:app];
        LEGACYRealmConfiguration *config = [user configurationWithPartitionValue:self.name];
        config.objectClasses = @[Person.self];
        return [self openRealmWithConfiguration:config];
    };

    LEGACYRealm *realm1 = openRealm(app1);
    LEGACYRealm *realm2 = openRealm(app2);

    CHECK_COUNT(0, Person, realm1);
    CHECK_COUNT(0, Person, realm2);

    @autoreleasepool {
        LEGACYRealm *realm = openRealm(app1);
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul]]];
        [self waitForUploadsForRealm:realm];
    }

    // realm2 should not see realm1's objcets despite being the same partition
    // as they're from different apps
    [self waitForDownloadsForRealm:realm1];
    [self waitForDownloadsForRealm:realm2];
    CHECK_COUNT(2, Person, realm1);
    CHECK_COUNT(0, Person, realm2);

    @autoreleasepool {
        LEGACYRealm *realm = openRealm(app2);
        [self addPersonsToRealm:realm
                        persons:@[[Person ringo], [Person george]]];
        [self waitForUploadsForRealm:realm];
    }

    [self waitForDownloadsForRealm:realm1];
    [self waitForDownloadsForRealm:realm2];
    CHECK_COUNT(2, Person, realm1);
    CHECK_COUNT(2, Person, realm2);

    XCTAssertEqual([Person objectsInRealm:realm1 where:@"firstName = 'John'"].count, 1UL);
    XCTAssertEqual([Person objectsInRealm:realm1 where:@"firstName = 'Paul'"].count, 1UL);
    XCTAssertEqual([Person objectsInRealm:realm1 where:@"firstName = 'Ringo'"].count, 0UL);
    XCTAssertEqual([Person objectsInRealm:realm1 where:@"firstName = 'George'"].count, 0UL);

    XCTAssertEqual([Person objectsInRealm:realm2 where:@"firstName = 'John'"].count, 0UL);
    XCTAssertEqual([Person objectsInRealm:realm2 where:@"firstName = 'Paul'"].count, 0UL);
    XCTAssertEqual([Person objectsInRealm:realm2 where:@"firstName = 'Ringo'"].count, 1UL);
    XCTAssertEqual([Person objectsInRealm:realm2 where:@"firstName = 'George'"].count, 1UL);
}

- (void)testSessionRefresh {
    LEGACYUser *user = [self createUser];

    // Should result in an access token error followed by a refresh when we
    // open the Realm which is entirely transparent to the user
    user._syncUser->update_access_token(self.badAccessToken.UTF8String);
    LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user];

    LEGACYRealm *realm2 = [self openRealm];
    [self addPersonsToRealm:realm2
                    persons:@[[Person john],
                              [Person paul],
                              [Person ringo],
                              [Person george]]];
    [self waitForUploadsForRealm:realm2];
    [self waitForDownloadsForRealm:realm];
    CHECK_COUNT(4, Person, realm);
}

- (void)testDeleteObjects {
    LEGACYRealm *realm1 = [self openRealm];
    [self addPersonsToRealm:realm1 persons:@[[Person john]]];
    [self waitForUploadsForRealm:realm1];
    CHECK_COUNT(1, Person, realm1);

    LEGACYRealm *realm2 = [self openRealm];
    CHECK_COUNT(1, Person, realm2);
    [realm2 beginWriteTransaction];
    [realm2 deleteAllObjects];
    [realm2 commitWriteTransaction];
    [self waitForUploadsForRealm:realm2];

    [self waitForDownloadsForRealm:realm1];
    CHECK_COUNT(0, Person, realm1);
}

- (void)testIncomingSyncWritesTriggerNotifications {
    LEGACYRealm *syncRealm = [self openRealm];
    LEGACYRealm *asyncRealm = [self asyncOpenRealmWithConfiguration:self.configuration];
    LEGACYRealm *writeRealm = [self openRealm];

    __block XCTestExpectation *ex = [self expectationWithDescription:@"got initial notification"];
    ex.expectedFulfillmentCount = 2;
    LEGACYNotificationToken *token1 = [[Person allObjectsInRealm:syncRealm] addNotificationBlock:^(LEGACYResults *, LEGACYCollectionChange *, NSError *) {
        [ex fulfill];
    }];
    LEGACYNotificationToken *token2 = [[Person allObjectsInRealm:asyncRealm] addNotificationBlock:^(LEGACYResults *, LEGACYCollectionChange *, NSError *) {
        [ex fulfill];
    }];
    [self waitForExpectations:@[ex] timeout:5.0];

    ex = [self expectationWithDescription:@"got update notification"];
    ex.expectedFulfillmentCount = 2;
    [self addPersonsToRealm:writeRealm persons:@[[Person john]]];
    [self waitForExpectations:@[ex] timeout:5.0];

    [token1 invalidate];
    [token2 invalidate];
}

#pragma mark - LEGACYValue Sync with missing schema

- (void)testMissingSchema {
    @autoreleasepool {
        LEGACYRealm *realm = [self openRealm];
        AllTypesSyncObject *obj = [[AllTypesSyncObject alloc] initWithValue:[AllTypesSyncObject values:0]];
        LEGACYSetSyncObject *o = [LEGACYSetSyncObject new];
        Person *p = [Person john];
        [o.anySet addObjects:@[p]];
        obj.anyCol = o;
        obj.objectCol = p;
        [realm beginWriteTransaction];
        [realm addObject:obj];
        [realm commitWriteTransaction];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(1, AllTypesSyncObject, realm);
    }

    LEGACYUser *user = [self createUser];
    auto c = [user configurationWithPartitionValue:self.name];
    c.objectClasses = @[Person.self, AllTypesSyncObject.self];
    LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:c error:nil];
    [self waitForDownloadsForRealm:realm];
    LEGACYResults<AllTypesSyncObject *> *res = [AllTypesSyncObject allObjectsInRealm:realm];
    AllTypesSyncObject *o = res.firstObject;
    Person *p = o.objectCol;
    LEGACYSet<LEGACYValue> *anySet = ((LEGACYObject *)o.anyCol)[@"anySet"];
    XCTAssertTrue([anySet.allObjects[0][@"firstName"] isEqualToString:p.firstName]);
    [realm beginWriteTransaction];
    anySet.allObjects[0][@"firstName"] = @"Bob";
    [realm commitWriteTransaction];
    XCTAssertTrue([anySet.allObjects[0][@"firstName"] isEqualToString:p.firstName]);
    CHECK_COUNT(1, AllTypesSyncObject, realm);
}

#pragma mark - Encryption -

/// If client B encrypts its synced Realm, client A should be able to access that Realm with a different encryption key.
- (void)testEncryptedSyncedRealm {
    LEGACYUser *user = [self userForTest:_cmd];

    NSData *key = LEGACYGenerateKey();
    LEGACYRealm *realm = [self openRealmForPartitionValue:self.name
                                                  user:user
                                         encryptionKey:key
                                            stopPolicy:LEGACYSyncStopPolicyAfterChangesUploaded];

    if (self.isParent) {
        CHECK_COUNT(0, Person, realm);
        LEGACYRunChildAndWait();
        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
    } else {
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
    }
}

/// If an encrypted synced Realm is re-opened with the wrong key, throw an exception.
- (void)testEncryptedSyncedRealmWrongKey {
    LEGACYUser *user = [self createUser];

    NSString *path;
    @autoreleasepool {
        LEGACYRealm *realm = [self openRealmForPartitionValue:self.name
                                                      user:user
                                             encryptionKey:LEGACYGenerateKey()
                                                stopPolicy:LEGACYSyncStopPolicyImmediately];
        path = realm.configuration.pathOnDisk;
    }
    [user.app.syncManager waitForSessionTermination];

    LEGACYRealmConfiguration *c = [LEGACYRealmConfiguration defaultConfiguration];
    c.fileURL = [NSURL fileURLWithPath:path];
    LEGACYAssertRealmExceptionContains([LEGACYRealm realmWithConfiguration:c error:nil],
                                    LEGACYErrorInvalidDatabase,
                                    @"Failed to open Realm file at path '%@': header has invalid mnemonic. The file is either not a Realm file, is an encrypted Realm file but no encryption key was supplied, or is corrupted.",
                                    c.fileURL.path);
    c.encryptionKey = LEGACYGenerateKey();
    LEGACYAssertRealmExceptionContains([LEGACYRealm realmWithConfiguration:c error:nil],
                                    LEGACYErrorInvalidDatabase,
                                    @"Failed to open Realm file at path '%@': Realm file decryption failed (Decryption failed: 'unable to decrypt after 0 seconds",
                                    c.fileURL.path);
}

#pragma mark - Multiple Realm Sync

/// If a client opens multiple Realms, there should be one session object for each Realm that was opened.
- (void)testMultipleRealmsSessions {
    NSString *partitionValueA = self.name;
    NSString *partitionValueB = [partitionValueA stringByAppendingString:@"bar"];
    NSString *partitionValueC = [partitionValueA stringByAppendingString:@"baz"];
    LEGACYUser *user = [self createUser];

    __attribute__((objc_precise_lifetime))
    LEGACYRealm *realmA = [self openRealmForPartitionValue:partitionValueA user:user];
    __attribute__((objc_precise_lifetime))
    LEGACYRealm *realmB = [self openRealmForPartitionValue:partitionValueB user:user];
    __attribute__((objc_precise_lifetime))
    LEGACYRealm *realmC = [self openRealmForPartitionValue:partitionValueC user:user];
    // Make sure there are three active sessions for the user.
    XCTAssertEqual(user.allSessions.count, 3U);
    XCTAssertNotNil([user sessionForPartitionValue:partitionValueA],
                    @"Expected to get a session for partition value A");
    XCTAssertNotNil([user sessionForPartitionValue:partitionValueB],
                    @"Expected to get a session for partition value B");
    XCTAssertNotNil([user sessionForPartitionValue:partitionValueC],
                    @"Expected to get a session for partition value C");
    XCTAssertEqual(realmA.syncSession.state, LEGACYSyncSessionStateActive);
    XCTAssertEqual(realmB.syncSession.state, LEGACYSyncSessionStateActive);
    XCTAssertEqual(realmC.syncSession.state, LEGACYSyncSessionStateActive);
}

/// A client should be able to open multiple Realms and add objects to each of them.
- (void)testMultipleRealmsAddObjects {
    NSString *partitionValueA = self.name;
    NSString *partitionValueB = [partitionValueA stringByAppendingString:@"bar"];
    NSString *partitionValueC = [partitionValueA stringByAppendingString:@"baz"];
    LEGACYUser *user = [self userForTest:_cmd];

    LEGACYRealm *realmA = [self openRealmForPartitionValue:partitionValueA user:user];
    LEGACYRealm *realmB = [self openRealmForPartitionValue:partitionValueB user:user];
    LEGACYRealm *realmC = [self openRealmForPartitionValue:partitionValueC user:user];

    if (self.isParent) {
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(0, Person, realmB);
        CHECK_COUNT(0, Person, realmC);
        LEGACYRunChildAndWait();
        [self waitForDownloadsForRealm:realmA];
        [self waitForDownloadsForRealm:realmB];
        [self waitForDownloadsForRealm:realmC];
        CHECK_COUNT(3, Person, realmA);
        CHECK_COUNT(2, Person, realmB);
        CHECK_COUNT(5, Person, realmC);

        LEGACYResults *resultsA = [Person objectsInRealm:realmA where:@"firstName == %@", @"Ringo"];
        LEGACYResults *resultsB = [Person objectsInRealm:realmB where:@"firstName == %@", @"Ringo"];

        XCTAssertEqual([resultsA count], 1UL);
        XCTAssertEqual([resultsB count], 0UL);
    } else {
        // Add objects.
        [self addPersonsToRealm:realmA
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo]]];
        [self addPersonsToRealm:realmB
                        persons:@[[Person john],
                                  [Person paul]]];
        [self addPersonsToRealm:realmC
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george],
                                  [Person ringo]]];
        [self waitForUploadsForRealm:realmA];
        [self waitForUploadsForRealm:realmB];
        [self waitForUploadsForRealm:realmC];
        CHECK_COUNT(3, Person, realmA);
        CHECK_COUNT(2, Person, realmB);
        CHECK_COUNT(5, Person, realmC);
    }
}

/// A client should be able to open multiple Realms and delete objects from each of them.
- (void)testMultipleRealmsDeleteObjects {
    NSString *partitionValueA = self.name;
    NSString *partitionValueB = [partitionValueA stringByAppendingString:@"bar"];
    NSString *partitionValueC = [partitionValueA stringByAppendingString:@"baz"];
    LEGACYUser *user = [self userForTest:_cmd];
    LEGACYRealm *realmA = [self openRealmForPartitionValue:partitionValueA user:user];
    LEGACYRealm *realmB = [self openRealmForPartitionValue:partitionValueB user:user];
    LEGACYRealm *realmC = [self openRealmForPartitionValue:partitionValueC user:user];

    if (self.isParent) {
        [self addPersonsToRealm:realmA
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george]]];
        [self addPersonsToRealm:realmB
                        persons:@[[Person john],
                                  [Person paul],
                                  [Person ringo],
                                  [Person george],
                                  [Person george]]];
        [self addPersonsToRealm:realmC
                        persons:@[[Person john],
                                  [Person paul]]];

        [self waitForUploadsForRealm:realmA];
        [self waitForUploadsForRealm:realmB];
        [self waitForUploadsForRealm:realmC];
        CHECK_COUNT(4, Person, realmA);
        CHECK_COUNT(5, Person, realmB);
        CHECK_COUNT(2, Person, realmC);
        LEGACYRunChildAndWait();
        [self waitForDownloadsForRealm:realmA];
        [self waitForDownloadsForRealm:realmB];
        [self waitForDownloadsForRealm:realmC];
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(0, Person, realmB);
        CHECK_COUNT(0, Person, realmC);
    } else {
        // Delete all the objects from the Realms.
        CHECK_COUNT(4, Person, realmA);
        CHECK_COUNT(5, Person, realmB);
        CHECK_COUNT(2, Person, realmC);
        [realmA beginWriteTransaction];
        [realmA deleteAllObjects];
        [realmA commitWriteTransaction];
        [realmB beginWriteTransaction];
        [realmB deleteAllObjects];
        [realmB commitWriteTransaction];
        [realmC beginWriteTransaction];
        [realmC deleteAllObjects];
        [realmC commitWriteTransaction];
        [self waitForUploadsForRealm:realmA];
        [self waitForUploadsForRealm:realmB];
        [self waitForUploadsForRealm:realmC];
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(0, Person, realmB);
        CHECK_COUNT(0, Person, realmC);
    }
}

#pragma mark - Session Lifetime
/// When a session opened by a Realm goes out of scope, it should stay alive long enough to finish any waiting uploads.
- (void)testUploadChangesWhenRealmOutOfScope {
    const NSInteger OBJECT_COUNT = 3;

    // Open the Realm in an autorelease pool so that it is destroyed as soon as possible.
    @autoreleasepool {
        LEGACYRealm *realm = [self openRealm];
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul], [Person ringo]]];
        CHECK_COUNT(OBJECT_COUNT, Person, realm);
    }

    [self.app.syncManager waitForSessionTermination];

    LEGACYRealm *realm = [self openRealm];
    CHECK_COUNT(OBJECT_COUNT, Person, realm);
}

#pragma mark - Logging Back In

/// A Realm that was opened before a user logged out should be able to resume uploading if the user logs back in.
- (void)testLogBackInSameRealmUpload {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name
                                                        register:self.isParent];
    LEGACYUser *user = [self logInUserForCredentials:credentials];

    LEGACYRealmConfiguration *config;
    @autoreleasepool {
        LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user];
        config = realm.configuration;
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        CHECK_COUNT(1, Person, realm);
        [self waitForUploadsForRealm:realm];
        // Log out the user out and back in
        [self logOutUser:user];
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul], [Person ringo]]];
        user = [self logInUserForCredentials:credentials];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(4, Person, realm);
        [realm.syncSession suspend];
        [self.app.syncManager waitForSessionTermination];
    }

    // Verify that the post-login objects were actually synced
    XCTAssertTrue([LEGACYRealm deleteFilesForConfiguration:config error:nil]);
    LEGACYRealm *realm = [self openRealm];
    CHECK_COUNT(4, Person, realm);
}

/// A Realm that was opened before a user logged out should be able to resume downloading if the user logs back in.
- (void)testLogBackInSameRealmDownload {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name
                                                        register:self.isParent];
    LEGACYUser *user = [self logInUserForCredentials:credentials];
    LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user];

    if (self.isParent) {
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        CHECK_COUNT(1, Person, realm);
        [self waitForUploadsForRealm:realm];
        // Log out the user.
        [self logOutUser:user];
        // Log the user back in.
        user = [self logInUserForCredentials:credentials];

        LEGACYRunChildAndWait();

        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(3, Person, realm);
    } else {
        [self addPersonsToRealm:realm persons:@[[Person john], [Person paul]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(3, Person, realm);
    }
}

/// A Realm that was opened while a user was logged out should be able to start uploading if the user logs back in.
- (void)testLogBackInDeferredRealmUpload {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name register:YES];
    LEGACYUser *user = [self logInUserForCredentials:credentials];
    [self logOutUser:user];

    // Open a Realm after the user's been logged out.
    LEGACYRealm *realm = [self immediatelyOpenRealmForPartitionValue:self.name user:user];

    [self addPersonsToRealm:realm persons:@[[Person john]]];
    CHECK_COUNT(1, Person, realm);

    [self logInUserForCredentials:credentials];
    [self addPersonsToRealm:realm
                    persons:@[[Person john], [Person paul], [Person ringo]]];
    [self waitForUploadsForRealm:realm];
    CHECK_COUNT(4, Person, realm);

    LEGACYRealm *realm2 = [self openRealm];
    CHECK_COUNT(4, Person, realm2);
}

/// A Realm that was opened while a user was logged out should be able to start downloading if the user logs back in.
- (void)testLogBackInDeferredRealmDownload {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name
                                                        register:self.isParent];
    LEGACYUser *user = [self logInUserForCredentials:credentials];

    if (self.isParent) {
        [self logOutUser:user];
        LEGACYRunChildAndWait();

        // Open a Realm after the user's been logged out.
        LEGACYRealm *realm = [self immediatelyOpenRealmForPartitionValue:self.name user:user];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        CHECK_COUNT(1, Person, realm);

        user = [self logInUserForCredentials:credentials];
        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(4, Person, realm);

    } else {
        LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user];
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul], [Person ringo]]];
        [self waitForUploadsForRealm:realm];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(3, Person, realm);
    }
}

/// After logging back in, a Realm whose path has been opened for the first time should properly upload changes.
- (void)testLogBackInOpenFirstTimePathUpload {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name register:YES];
    LEGACYUser *user = [self logInUserForCredentials:credentials];
    [self logOutUser:user];

    @autoreleasepool {
        auto c = [user configurationWithPartitionValue:self.name];
        c.objectClasses = @[Person.self];
        LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:c error:nil];
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul]]];

        [self logInUserForCredentials:credentials];
        [self waitForUploadsForRealm:realm];
    }

    LEGACYRealm *realm = [self openRealm];
    CHECK_COUNT(2, Person, realm);
}

/// After logging back in, a Realm whose path has been opened for the first time should properly download changes.
- (void)testLogBackInOpenFirstTimePathDownload {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name register:YES];
    LEGACYUser *user = [self logInUserForCredentials:credentials];
    [self logOutUser:user];

    auto c = [user configurationWithPartitionValue:self.name];
    c.objectClasses = @[Person.self];
    LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:c error:nil];

    @autoreleasepool {
        LEGACYRealm *realm = [self openRealm];
        [self addPersonsToRealm:realm
                        persons:@[[Person john], [Person paul]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(2, Person, realm);
    }

    CHECK_COUNT(0, Person, realm);
    [self logInUserForCredentials:credentials];
    [self waitForDownloadsForRealm:realm];
    CHECK_COUNT(2, Person, realm);
}

/// If a client logs in, connects, logs out, and logs back in, sync should properly upload changes for a new
/// `LEGACYRealm` that is opened for the same path as a previously-opened Realm.
- (void)testLogBackInReopenRealmUpload {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name
                                                        register:self.isParent];
    LEGACYUser *user = [self logInUserForCredentials:credentials];

    @autoreleasepool {
        LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
        [self logOutUser:user];
        user = [self logInUserForCredentials:credentials];
    }

    LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user];
    [self addPersonsToRealm:realm
                    persons:@[[Person john], [Person paul], [Person george], [Person ringo]]];
    CHECK_COUNT(5, Person, realm);
    [self waitForUploadsForRealm:realm];

    LEGACYRealm *realm2 = [self openRealmForPartitionValue:self.name user:self.createUser];
    CHECK_COUNT(5, Person, realm2);
}

/// If a client logs in, connects, logs out, and logs back in, sync should properly download changes for a new
/// `LEGACYRealm` that is opened for the same path as a previously-opened Realm.
- (void)testLogBackInReopenRealmDownload {
    LEGACYCredentials *credentials = [self basicCredentialsWithName:self.name
                                                        register:self.isParent];
    LEGACYUser *user = [self logInUserForCredentials:credentials];

    LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user];
    [self addPersonsToRealm:realm persons:@[[Person john]]];
    [self waitForUploadsForRealm:realm];
    XCTAssert([Person allObjectsInRealm:realm].count == 1, @"Expected 1 item");
    [self logOutUser:user];
    user = [self logInUserForCredentials:credentials];
    LEGACYRealm *realm2 = [self openRealmForPartitionValue:self.name user:self.createUser];
    CHECK_COUNT(1, Person, realm2);
    [self addPersonsToRealm:realm2
                    persons:@[[Person john], [Person paul], [Person george], [Person ringo]]];
    [self waitForUploadsForRealm:realm2];
    CHECK_COUNT(5, Person, realm2);

    // Open the Realm again and get the items.
    realm = [self openRealmForPartitionValue:self.name user:user];
    CHECK_COUNT(5, Person, realm2);
}

#pragma mark - Session suspend and resume

- (void)testSuspendAndResume {
    LEGACYUser *user = [self userForTest:_cmd];

    __attribute__((objc_precise_lifetime))
    LEGACYRealm *realmA = [self openRealmForPartitionValue:@"suspend and resume 1" user:user];
    __attribute__((objc_precise_lifetime))
    LEGACYRealm *realmB = [self openRealmForPartitionValue:@"suspend and resume 2" user:user];
    if (self.isParent) {
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(0, Person, realmB);

        // Suspend the session for realm A and then add an object to each Realm
        LEGACYSyncSession *sessionA = [LEGACYSyncSession sessionForRealm:realmA];
        LEGACYSyncSession *sessionB = [LEGACYSyncSession sessionForRealm:realmB];
        XCTAssertEqual(sessionB.state, LEGACYSyncSessionStateActive);
        [sessionA suspend];
        XCTAssertEqual(realmB.syncSession.state, LEGACYSyncSessionStateActive);

        [self addPersonsToRealm:realmA persons:@[[Person john]]];
        [self addPersonsToRealm:realmB persons:@[[Person ringo]]];
        [self waitForUploadsForRealm:realmB];
        LEGACYRunChildAndWait();

        // A should still be 1 since it's suspended. If it wasn't suspended, it
        // should have downloaded before B due to the ordering in the child.
        [self waitForDownloadsForRealm:realmB];
        CHECK_COUNT(1, Person, realmA);
        CHECK_COUNT(3, Person, realmB);

        // A should see the other two from the child after resuming
        [sessionA resume];
        [self waitForDownloadsForRealm:realmA];
        CHECK_COUNT(3, Person, realmA);
    } else {
        // Child shouldn't see the object in A
        CHECK_COUNT(0, Person, realmA);
        CHECK_COUNT(1, Person, realmB);
        [self addPersonsToRealm:realmA
                        persons:@[[Person john], [Person paul]]];
        [self waitForUploadsForRealm:realmA];
        [self addPersonsToRealm:realmB
                        persons:@[[Person john], [Person paul]]];
        [self waitForUploadsForRealm:realmB];
        CHECK_COUNT(2, Person, realmA);
        CHECK_COUNT(3, Person, realmB);
    }
}

#pragma mark - Client reset

/// Ensure that a client reset error is propagated up to the binding successfully.
- (void)testClientReset {
    LEGACYUser *user = [self userForTest:_cmd];
    // Open the Realm
    __attribute__((objc_precise_lifetime))
    LEGACYRealm *realm = [self openRealmForPartitionValue:@"realm_id"
                                                  user:user
                                       clientResetMode:LEGACYClientResetModeManual];

    __block NSError *theError = nil;
    XCTestExpectation *ex = [self expectationWithDescription:@"Waiting for error handler to be called..."];
    [self.app syncManager].errorHandler = ^void(NSError *error, LEGACYSyncSession *) {
        theError = error;
        [ex fulfill];
    };
    [user simulateClientResetErrorForSession:@"realm_id"];
    [self waitForExpectationsWithTimeout:30 handler:nil];
    XCTAssertNotNil(theError);
    XCTAssertTrue(theError.code == LEGACYSyncErrorClientResetError);
    NSString *pathValue = [theError rlmSync_clientResetBackedUpRealmPath];
    XCTAssertNotNil(pathValue);
    // Sanity check the recovery path.
    NSString *recoveryPath = [NSString stringWithFormat:@"mongodb-realm/%@/recovered-realms", self.appId];
    XCTAssertTrue([pathValue rangeOfString:recoveryPath].location != NSNotFound);
    XCTAssertNotNil([theError rlmSync_errorActionToken]);
}

/// Test manually initiating client reset.
- (void)testClientResetManualInitiation {
    LEGACYUser *user = [self createUser];

    __block NSError *theError = nil;
    @autoreleasepool {
        __attribute__((objc_precise_lifetime))
        LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user
                                           clientResetMode:LEGACYClientResetModeManual];
        XCTestExpectation *ex = [self expectationWithDescription:@"Waiting for error handler to be called..."];
        self.app.syncManager.errorHandler = ^(NSError *error, LEGACYSyncSession *) {
            theError = error;
            [ex fulfill];
        };
        [user simulateClientResetErrorForSession:self.name];
        [self waitForExpectationsWithTimeout:30 handler:nil];
        XCTAssertNotNil(theError);
    }

    // At this point the Realm should be invalidated and client reset should be possible.
    NSString *pathValue = [theError rlmSync_clientResetBackedUpRealmPath];
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:pathValue]);
    [LEGACYSyncSession immediatelyHandleError:theError.rlmSync_errorActionToken
                               syncManager:self.app.syncManager];
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:pathValue]);
}

- (void)testSetClientResetMode {
    LEGACYUser *user = [self createUser];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    LEGACYRealmConfiguration *config = [user configurationWithPartitionValue:self.name
                                                          clientResetMode:LEGACYClientResetModeDiscardLocal];
    XCTAssertEqual(config.syncConfiguration.clientResetMode, LEGACYClientResetModeDiscardLocal);
    #pragma clang diagnostic pop

    // Default is recover
    config = [user configurationWithPartitionValue:self.name];
    XCTAssertEqual(config.syncConfiguration.clientResetMode, LEGACYClientResetModeRecoverUnsyncedChanges);

    LEGACYSyncErrorReportingBlock block = ^(NSError *, LEGACYSyncSession *) {
        XCTFail("Should never hit");
    };
    LEGACYAssertThrowsWithReason([user configurationWithPartitionValue:self.name
                                                    clientResetMode:LEGACYClientResetModeDiscardUnsyncedChanges
                                           manualClientResetHandler:block],
                              @"A manual client reset handler can only be set with LEGACYClientResetModeManual");
}

- (void)testSetClientResetCallbacks {
    LEGACYUser *user = [self createUser];

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    LEGACYRealmConfiguration *config = [user configurationWithPartitionValue:self.name
                                                          clientResetMode:LEGACYClientResetModeDiscardLocal];

    XCTAssertNil(config.syncConfiguration.beforeClientReset);
    XCTAssertNil(config.syncConfiguration.afterClientReset);

    LEGACYClientResetBeforeBlock beforeBlock = ^(LEGACYRealm *local __unused) {
        XCTAssert(false, @"Should not execute callback");
    };
    LEGACYClientResetAfterBlock afterBlock = ^(LEGACYRealm *before __unused, LEGACYRealm *after __unused) {
        XCTAssert(false, @"Should not execute callback");
    };
    LEGACYRealmConfiguration *config2 = [user configurationWithPartitionValue:self.name
                                                           clientResetMode:LEGACYClientResetModeDiscardLocal
                                                         notifyBeforeReset:beforeBlock
                                                          notifyAfterReset:afterBlock];
    XCTAssertNotNil(config2.syncConfiguration.beforeClientReset);
    XCTAssertNotNil(config2.syncConfiguration.afterClientReset);
    #pragma clang diagnostic pop

}

// TODO: Consider testing with sync_config->on_sync_client_event_hook or a client reset
- (void)testBeforeClientResetCallbackNotVersioned {
    // Setup sync config
    LEGACYSyncConfiguration *syncConfig = [[LEGACYSyncConfiguration alloc] initWithRawConfig:{} path:""];
    XCTestExpectation *beforeExpectation = [self expectationWithDescription:@"block called once"];
    syncConfig.clientResetMode = LEGACYClientResetModeRecoverUnsyncedChanges;
    syncConfig.beforeClientReset = ^(LEGACYRealm *beforeFrozen) {
        XCTAssertNotEqual(LEGACYNotVersioned, beforeFrozen->_realm->schema_version());
        [beforeExpectation fulfill];
    };
    auto& beforeWrapper = syncConfig.rawConfiguration.notify_before_client_reset;

    // Setup a realm with a versioned schema
    LEGACYRealmConfiguration *configVersioned = [LEGACYRealmConfiguration defaultConfiguration];
    configVersioned.fileURL = LEGACYTestRealmURL();
    @autoreleasepool {
        LEGACYRealm *versioned = [LEGACYRealm realmWithConfiguration:configVersioned error:nil];
        XCTAssertEqual(0U, versioned->_realm->schema_version());
    }
    std::shared_ptr<realm::Realm> versioned = realm::Realm::get_shared_realm(configVersioned.config);

    // Create a config that's not versioned.
    LEGACYRealmConfiguration *configUnversioned = [LEGACYRealmConfiguration defaultConfiguration];
    configUnversioned.configRef.schema_version = LEGACYNotVersioned;
    std::shared_ptr<realm::Realm> unversioned = realm::Realm::get_shared_realm(configUnversioned.config);

    XCTAssertNotEqual(versioned->schema_version(), LEGACYNotVersioned);
    XCTAssertEqual(unversioned->schema_version(), LEGACYNotVersioned);
    beforeWrapper(versioned); // one realm should invoke the block
    beforeWrapper(unversioned); // while the other should not invoke the block

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

// TODO: Consider testing with sync_config->on_sync_client_event_hook or a client reset
- (void)testAfterClientResetCallbackNotVersioned {
    // Setup sync config
    LEGACYSyncConfiguration *syncConfig = [[LEGACYSyncConfiguration alloc] initWithRawConfig:{} path:""];
    XCTestExpectation *afterExpectation = [self expectationWithDescription:@"block should not be called"];
    afterExpectation.inverted = true;

    syncConfig.clientResetMode = LEGACYClientResetModeRecoverUnsyncedChanges;
    syncConfig.afterClientReset = ^(LEGACYRealm * _Nonnull, LEGACYRealm * _Nonnull) {
        [afterExpectation fulfill];
    };
    auto& afterWrapper = syncConfig.rawConfiguration.notify_after_client_reset;

    // Create a config that's not versioned.
    LEGACYRealmConfiguration *configUnversioned = [LEGACYRealmConfiguration defaultConfiguration];
    configUnversioned.configRef.schema_version = LEGACYNotVersioned;
    std::shared_ptr<realm::Realm> unversioned = realm::Realm::get_shared_realm(configUnversioned.config);

    auto unversionedTsr = realm::ThreadSafeReference(unversioned);
    XCTAssertEqual(unversioned->schema_version(), LEGACYNotVersioned);
    afterWrapper(unversioned, std::move(unversionedTsr), false);

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - Progress Notifications

static const NSInteger NUMBER_OF_BIG_OBJECTS = 2;

- (void)populateData {
    NSURL *realmURL;
    LEGACYUser *user = [self createUser];
    @autoreleasepool {
        LEGACYRealm *realm = [self openRealmWithUser:user];
        realmURL = realm.configuration.fileURL;
        CHECK_COUNT(0, HugeSyncObject, realm);
        [realm beginWriteTransaction];
        for (NSInteger i = 0; i < NUMBER_OF_BIG_OBJECTS; i++) {
            [realm addObject:[HugeSyncObject hugeSyncObject]];
        }
        [realm commitWriteTransaction];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
    }
    [user.app.syncManager waitForSessionTermination];
    [self deleteRealmFileAtURL:realmURL];
}

- (void)testStreamingDownloadNotifier {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSession *session = realm.syncSession;
    XCTAssertNotNil(session);

    XCTestExpectation *ex = [self expectationWithDescription:@"streaming-download-notifier"];
    std::atomic<NSInteger> callCount{0};
    std::atomic<NSUInteger> transferred{0};
    std::atomic<NSUInteger> transferrable{0};
    BOOL hasBeenFulfilled = NO;
    LEGACYNotificationToken *token = [session
                                   addProgressNotificationForDirection:LEGACYSyncProgressDirectionDownload
                                   mode:LEGACYSyncProgressModeReportIndefinitely
                                   block:[&](NSUInteger xfr, NSUInteger xfb) {
        // Make sure the values are increasing, and update our stored copies.
        XCTAssertGreaterThanOrEqual(xfr, transferred.load());
        XCTAssertGreaterThanOrEqual(xfb, transferrable.load());
        transferred = xfr;
        transferrable = xfb;
        callCount++;
        if (transferrable > 0 && transferred >= transferrable && !hasBeenFulfilled) {
            [ex fulfill];
            hasBeenFulfilled = YES;
        }
    }];

    [self populateData];

    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [token invalidate];
    // The notifier should have been called at least twice: once at the beginning and at least once
    // to report progress.
    XCTAssertGreaterThan(callCount.load(), 1);
    XCTAssertGreaterThanOrEqual(transferred.load(), transferrable.load());
}

- (void)testStreamingUploadNotifier {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSession *session = realm.syncSession;
    XCTAssertNotNil(session);

    XCTestExpectation *ex = [self expectationWithDescription:@"streaming-upload-expectation"];
    std::atomic<NSInteger> callCount{0};
    std::atomic<NSUInteger> transferred{0};
    std::atomic<NSUInteger> transferrable{0};
    auto token = [session addProgressNotificationForDirection:LEGACYSyncProgressDirectionUpload
                                                         mode:LEGACYSyncProgressModeReportIndefinitely
                                                        block:[&](NSUInteger xfr, NSUInteger xfb) {
        // Make sure the values are increasing, and update our stored copies.
        XCTAssertGreaterThanOrEqual(xfr, transferred.load());
        XCTAssertGreaterThanOrEqual(xfb, transferrable.load());
        transferred = xfr;
        transferrable = xfb;
        callCount++;
        if (transferred > 0 && transferred >= transferrable && transferrable > 1000000 * NUMBER_OF_BIG_OBJECTS) {
            [ex fulfill];
        }
    }];

    // Upload lots of data
    [realm beginWriteTransaction];
    for (NSInteger i=0; i<NUMBER_OF_BIG_OBJECTS; i++) {
        [realm addObject:[HugeSyncObject hugeSyncObject]];
    }
    [realm commitWriteTransaction];

    // Wait for upload to begin and finish
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [token invalidate];

    // The notifier should have been called at least twice: once at the beginning and at least once
    // to report progress.
    XCTAssertGreaterThan(callCount.load(), 1);
    XCTAssertGreaterThanOrEqual(transferred.load(), transferrable.load());
}

#pragma mark - Download Realm

- (void)testDownloadRealm {
    [self populateData];

    XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
    LEGACYRealmConfiguration *c = [self configuration];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:c.pathOnDisk isDirectory:nil]);

    [LEGACYRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(LEGACYRealm *realm, NSError *error) {
        XCTAssertNil(error);
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
        [ex fulfill];
    }];
    NSUInteger (^fileSize)(NSString *) = ^NSUInteger(NSString *path) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        if (attributes)
            return [(NSNumber *)attributes[NSFileSize] unsignedLongLongValue];

        return 0;
    };
    XCTAssertNil(LEGACYGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    XCTAssertGreaterThan(fileSize(c.pathOnDisk), 0U);
    XCTAssertNil(LEGACYGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
}

- (void)testDownloadAlreadyOpenRealm {
    XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
    LEGACYRealmConfiguration *c = [self configuration];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:c.pathOnDisk isDirectory:nil]);
    LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:c error:nil];
    CHECK_COUNT(0, HugeSyncObject, realm);
    [self waitForUploadsForRealm:realm];
    [realm.syncSession suspend];

    [self populateData];

    auto fileSize = ^NSUInteger(NSString *path) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        return [(NSNumber *)attributes[NSFileSize] unsignedLongLongValue];
    };
    NSUInteger sizeBefore = fileSize(c.pathOnDisk);
    XCTAssertGreaterThan(sizeBefore, 0U);
    XCTAssertNotNil(LEGACYGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));

    [LEGACYRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(LEGACYRealm *realm, NSError *error) {
        XCTAssertNil(error);
        CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
        [ex fulfill];
    }];
    [realm.syncSession resume];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTAssertGreaterThan(fileSize(c.pathOnDisk), sizeBefore);
    XCTAssertNotNil(LEGACYGetAnyCachedRealmForPath(c.pathOnDisk.UTF8String));
    CHECK_COUNT(NUMBER_OF_BIG_OBJECTS, HugeSyncObject, realm);
}

- (void)testDownloadCancelsOnAuthError {
    auto c = [self configuration];
    [self setInvalidTokensForUser:c.syncConfiguration.user];
    auto ex = [self expectationWithDescription:@"async open"];
    [LEGACYRealm asyncOpenWithConfiguration:c callbackQueue:dispatch_get_main_queue()
                                callback:^(LEGACYRealm *realm, NSError *error) {
        XCTAssertNil(realm);
        LEGACYValidateError(error, LEGACYAppErrorDomain, LEGACYAppErrorUnknown,
                         @"Unable to refresh the user access token: signature is invalid");
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testCancelDownload {
    [self populateData];

    // Use a serial queue for asyncOpen to ensure that the first one adds
    // the completion block before the second one cancels it
    auto queue = dispatch_queue_create("io.realm.asyncOpen", 0);
    LEGACYSetAsyncOpenQueue(queue);

    XCTestExpectation *ex = [self expectationWithDescription:@"download-realm"];
    ex.expectedFulfillmentCount = 2;
    LEGACYRealmConfiguration *c = [self configuration];
    [LEGACYRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(LEGACYRealm *realm, NSError *error) {
        XCTAssertNil(realm);
        LEGACYValidateError(error, NSPOSIXErrorDomain, ECANCELED, @"Operation canceled");
        [ex fulfill];
    }];
    auto task = [LEGACYRealm asyncOpenWithConfiguration:c
                            callbackQueue:dispatch_get_main_queue()
                                 callback:^(LEGACYRealm *realm, NSError *error) {
        XCTAssertNil(realm);
        LEGACYValidateError(error, NSPOSIXErrorDomain, ECANCELED, @"Operation canceled");
        [ex fulfill];
    }];

    // The cancel needs to be scheduled after we've actually started the task,
    // which is itself async
    dispatch_sync(queue, ^{ [task cancel]; });
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testAsyncOpenProgressNotifications {
    [self populateData];

    XCTestExpectation *ex1 = [self expectationWithDescription:@"async open"];
    XCTestExpectation *ex2 = [self expectationWithDescription:@"download progress complete"];

    auto task = [LEGACYRealm asyncOpenWithConfiguration:self.configuration
                                       callbackQueue:dispatch_get_main_queue()
                                            callback:^(LEGACYRealm *realm, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(realm);
        [ex1 fulfill];
    }];
    [task addProgressNotificationBlock:^(NSUInteger transferredBytes, NSUInteger transferrableBytes) {
        if (transferrableBytes > 0 && transferredBytes == transferrableBytes) {
            [ex2 fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testAsyncOpenConnectionTimeout {
    TimeoutProxyServer *proxy = [[TimeoutProxyServer alloc] initWithPort:5678 targetPort:9090];
    NSError *error;
    [proxy startAndReturnError:&error];
    XCTAssertNil(error);

    LEGACYAppConfiguration *config = [[LEGACYAppConfiguration alloc]
                                   initWithBaseURL:@"http://localhost:9090"
                                   transport:[AsyncOpenConnectionTimeoutTransport new]
                                   defaultRequestTimeoutMS:60];
    LEGACYSyncTimeoutOptions *timeoutOptions = [LEGACYSyncTimeoutOptions new];
    timeoutOptions.connectTimeout = 1000.0;
    config.syncTimeouts = timeoutOptions;
    NSString *appId = [RealmServer.shared
                       createAppWithPartitionKeyType:@"string"
                       types:@[Person.self] persistent:false error:nil];
    LEGACYUser *user = [self createUserForApp:[LEGACYApp appWithId:appId configuration:config]];

    LEGACYRealmConfiguration *c = [user configurationWithPartitionValue:appId];
    c.objectClasses = @[Person.class];
    LEGACYSyncConfiguration *syncConfig = c.syncConfiguration;
    syncConfig.cancelAsyncOpenOnNonFatalErrors = true;
    c.syncConfiguration = syncConfig;

    // Set delay above the timeout so it should fail
    proxy.delay = 2.0;

    XCTestExpectation *ex = [self expectationWithDescription:@"async open"];
    [LEGACYRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(LEGACYRealm *realm, NSError *error) {
        LEGACYValidateError(error, NSPOSIXErrorDomain, ETIMEDOUT,
                         @"Sync connection was not fully established in time");
        XCTAssertNil(realm);
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];

    // Delay below the timeout should work
    proxy.delay = 0.5;

    ex = [self expectationWithDescription:@"async open"];
    [LEGACYRealm asyncOpenWithConfiguration:c
                           callbackQueue:dispatch_get_main_queue()
                                callback:^(LEGACYRealm *realm, NSError *error) {
        XCTAssertNotNil(realm);
        XCTAssertNil(error);
        [ex fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];

    [proxy stop];
}

#pragma mark - Compact on Launch

- (void)testCompactOnLaunch {
    LEGACYRealmConfiguration *config = self.configuration;
    NSString *path = config.fileURL.path;
    // Create a large object and then delete it in the next transaction so that
    // the file is bloated
    @autoreleasepool {
        LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:config error:nil];
        [realm beginWriteTransaction];
        [realm addObject:[HugeSyncObject hugeSyncObject]];
        [realm commitWriteTransaction];
        [self waitForUploadsForRealm:realm];

        [realm beginWriteTransaction];
        [realm deleteAllObjects];
        [realm commitWriteTransaction];
    }

    LEGACYWaitForRealmToClose(config.fileURL.path);

    auto fileManager = NSFileManager.defaultManager;
    auto initialSize = [[fileManager attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];

    // Reopen the file with a shouldCompactOnLaunch block and verify that it is
    // actually compacted
    __block bool blockCalled = false;
    __block NSUInteger usedSize = 0;
    config.shouldCompactOnLaunch = ^(NSUInteger, NSUInteger used) {
        usedSize = used;
        blockCalled = true;
        return YES;
    };

    @autoreleasepool {
        [LEGACYRealm realmWithConfiguration:config error:nil];
    }
    XCTAssertTrue(blockCalled);

    auto finalSize = [[fileManager attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];
    XCTAssertLessThan(finalSize, initialSize);
    XCTAssertLessThanOrEqual(finalSize, usedSize + realm::util::page_size());
}

- (void)testWriteCopy {
    LEGACYRealm *syncRealm = [self openRealm];
    [self addPersonsToRealm:syncRealm persons:@[[Person john]]];

    NSError *writeError;
    XCTAssertTrue([syncRealm writeCopyToURL:LEGACYTestRealmURL()
                              encryptionKey:syncRealm.configuration.encryptionKey
                                      error:&writeError]);
    XCTAssertNil(writeError);

    LEGACYRealmConfiguration *localConfig = [LEGACYRealmConfiguration new];
    localConfig.fileURL = LEGACYTestRealmURL();
    localConfig.objectClasses = @[Person.self];
    localConfig.schemaVersion = 1;

    LEGACYRealm *localCopy = [LEGACYRealm realmWithConfiguration:localConfig error:nil];
    XCTAssertEqual(1U, [Person allObjectsInRealm:localCopy].count);
}

#pragma mark - Read Only

- (void)testOpenSynchronouslyInReadOnlyBeforeRemoteSchemaIsInitialized {
    LEGACYUser *user = [self userForTest:_cmd];

    if (self.isParent) {
        LEGACYRealmConfiguration *config = [user configurationWithPartitionValue:self.name];
        config.objectClasses = self.defaultObjectTypes;
        config.readOnly = true;
        LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:config error:nil];
        CHECK_COUNT(0, Person, realm);
        LEGACYRunChildAndWait();
        [self waitForDownloadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
    } else {
        LEGACYRealm *realm = [self openRealmForPartitionValue:self.name user:user];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
        CHECK_COUNT(1, Person, realm);
    }
}

- (void)testAddPropertyToReadOnlyRealmWithExistingLocalCopy {
    @autoreleasepool {
        LEGACYRealm *realm = [self openRealm];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
    }

    LEGACYRealmConfiguration *config = [self.createUser configurationWithPartitionValue:self.name];
    config.objectClasses = self.defaultObjectTypes;
    config.readOnly = true;
    @autoreleasepool {
        LEGACYRealm *realm = [self asyncOpenRealmWithConfiguration:config];
        CHECK_COUNT(1, Person, realm);
    }

    LEGACYObjectSchema *objectSchema = [LEGACYObjectSchema schemaForObjectClass:Person.class];
    objectSchema.properties = [LEGACYObjectSchema schemaForObjectClass:HugeSyncObject.class].properties;
    config.customSchema = [[LEGACYSchema alloc] init];
    config.customSchema.objectSchema = @[objectSchema];

    LEGACYAssertThrowsWithReason([LEGACYRealm realmWithConfiguration:config error:nil],
                              @"Property 'Person.dataProp' has been added.");

    @autoreleasepool {
        NSError *error = [self asyncOpenErrorWithConfiguration:config];
        XCTAssertNotEqual([error.localizedDescription rangeOfString:@"Property 'Person.dataProp' has been added."].location,
                          NSNotFound);
    }
}

- (void)testAddPropertyToReadOnlyRealmWithAsyncOpen {
    @autoreleasepool {
        LEGACYRealm *realm = [self openRealm];
        [self addPersonsToRealm:realm persons:@[[Person john]]];
        [self waitForUploadsForRealm:realm];
    }
    [self.app.syncManager waitForSessionTermination];

    LEGACYRealmConfiguration *config = [self configuration];
    config.readOnly = true;

    LEGACYObjectSchema *objectSchema = [LEGACYObjectSchema schemaForObjectClass:Person.class];
    objectSchema.properties = [LEGACYObjectSchema schemaForObjectClass:HugeSyncObject.class].properties;
    config.customSchema = [[LEGACYSchema alloc] init];
    config.customSchema.objectSchema = @[objectSchema];

    @autoreleasepool {
        NSError *error = [self asyncOpenErrorWithConfiguration:config];
        XCTAssert([error.localizedDescription containsString:@"Property 'Person.dataProp' has been added."]);
    }
}

- (void)testSyncConfigShouldNotMigrate {
    LEGACYRealm *realm = [self openRealm];
    LEGACYAssertThrowsWithReason(realm.configuration.deleteRealmIfMigrationNeeded = YES,
                              @"Cannot set 'deleteRealmIfMigrationNeeded' when sync is enabled");

    LEGACYRealmConfiguration *localRealmConfiguration = [LEGACYRealmConfiguration defaultConfiguration];
    XCTAssertNoThrow(localRealmConfiguration.deleteRealmIfMigrationNeeded = YES);
}

#pragma mark - Write Copy For Configuration

- (void)testWriteCopyForConfigurationLocalToSync {
    LEGACYRealmConfiguration *localConfig = [LEGACYRealmConfiguration new];
    localConfig.objectClasses = @[Person.class];
    localConfig.fileURL = LEGACYTestRealmURL();

    LEGACYRealmConfiguration *syncConfig = self.configuration;
    syncConfig.objectClasses = @[Person.class];

    LEGACYRealm *localRealm = [LEGACYRealm realmWithConfiguration:localConfig error:nil];
    [localRealm transactionWithBlock:^{
        [localRealm addObject:[Person ringo]];
    }];

    [localRealm writeCopyForConfiguration:syncConfig error:nil];

    LEGACYRealm *syncedRealm = [LEGACYRealm realmWithConfiguration:syncConfig error:nil];
    XCTAssertEqual([[Person allObjectsInRealm:syncedRealm] objectsWhere:@"firstName = 'Ringo'"].count, 1U);

    [self waitForDownloadsForRealm:syncedRealm];
    [syncedRealm transactionWithBlock:^{
        [syncedRealm addObject:[Person john]];
    }];
    [self waitForUploadsForRealm:syncedRealm];

    LEGACYResults<Person *> *syncedResults = [Person allObjectsInRealm:syncedRealm];
    XCTAssertEqual([syncedResults objectsWhere:@"firstName = 'Ringo'"].count, 1U);
    XCTAssertEqual([syncedResults objectsWhere:@"firstName = 'John'"].count, 1U);
}

- (void)testWriteCopyForConfigurationSyncToSyncRealmError {
    LEGACYRealmConfiguration *syncConfig = self.configuration;
    LEGACYRealmConfiguration *syncConfig2 = self.configuration;

    LEGACYRealm *syncedRealm = [LEGACYRealm realmWithConfiguration:syncConfig error:nil];
    [syncedRealm.syncSession suspend];
    [syncedRealm transactionWithBlock:^{
        [syncedRealm addObject:[Person ringo]];
    }];
    // Cannot export a synced realm as not all changes have been synced.
    NSError *error;
    [syncedRealm writeCopyForConfiguration:syncConfig2 error:&error];
    XCTAssertEqual(error.code, LEGACYErrorFail);
    XCTAssertEqualObjects(error.localizedDescription,
                          @"All client changes must be integrated in server before writing copy");
}

- (void)testWriteCopyForConfigurationLocalRealmForSyncWithExistingData {
    LEGACYRealmConfiguration *initialSyncConfig = self.configuration;
    initialSyncConfig.objectClasses = @[Person.class];

    // Make sure objects with confliciting primary keys sync ok.
    LEGACYObjectId *conflictingObjectId = [LEGACYObjectId objectId];
    Person *person = [Person ringo];
    person._id = conflictingObjectId;

    LEGACYRealm *initialRealm = [LEGACYRealm realmWithConfiguration:initialSyncConfig error:nil];
    [initialRealm transactionWithBlock:^{
        [initialRealm addObject:person];
        [initialRealm addObject:[Person john]];
    }];
    [self waitForUploadsForRealm:initialRealm];

    LEGACYRealmConfiguration *localConfig = [LEGACYRealmConfiguration new];
    localConfig.objectClasses = @[Person.class];
    localConfig.fileURL = LEGACYTestRealmURL();

    LEGACYRealmConfiguration *syncConfig = self.configuration;
    syncConfig.objectClasses = @[Person.class];

    LEGACYRealm *localRealm = [LEGACYRealm realmWithConfiguration:localConfig error:nil];
    // `person2` will override what was previously stored on the server.
    Person *person2 = [Person new];
    person2._id = conflictingObjectId;
    person2.firstName = @"John";
    person2.lastName = @"Doe";

    [localRealm transactionWithBlock:^{
        [localRealm addObject:person2];
        [localRealm addObject:[Person george]];
    }];

    [localRealm writeCopyForConfiguration:syncConfig error:nil];

    LEGACYRealm *syncedRealm = [LEGACYRealm realmWithConfiguration:syncConfig error:nil];
    [self waitForDownloadsForRealm:syncedRealm];
    XCTAssertEqual([syncedRealm allObjects:@"Person"].count, 3U);
    [syncedRealm transactionWithBlock:^{
        [syncedRealm addObject:[Person stuart]];
    }];

    [self waitForUploadsForRealm:syncedRealm];
    LEGACYResults<Person *> *syncedResults = [Person allObjectsInRealm:syncedRealm];

    NSPredicate *p = [NSPredicate predicateWithFormat:@"firstName = 'John' AND lastName = 'Doe' AND _id = %@", conflictingObjectId];
    XCTAssertEqual([syncedResults objectsWithPredicate:p].count, 1U);
    XCTAssertEqual([syncedRealm allObjects:@"Person"].count, 4U);
}

#pragma mark - File paths

static NSString *newPathForPartitionValue(LEGACYUser *user, id<LEGACYBSON> partitionValue) {
    std::stringstream s;
    s << LEGACYConvertRLMBSONToBson(partitionValue);
    // Intentionally not passing the correct partition value here as we (accidentally?)
    // don't use the filename generated from the partition value
    realm::SyncConfig config(user._syncUser, "null");
    return @(user._syncUser->sync_manager()->path_for_realm(config, s.str()).c_str());
}

- (void)testSyncFilePaths {
    LEGACYUser *user = self.anonymousUser;
    auto configuration = [user configurationWithPartitionValue:@"abc"];
    XCTAssertTrue([configuration.fileURL.path
                   hasSuffix:([NSString stringWithFormat:@"mongodb-realm/%@/%@/%%22abc%%22.realm",
                               self.appId, user.identifier])]);
    configuration = [user configurationWithPartitionValue:@123];
    XCTAssertTrue([configuration.fileURL.path
                   hasSuffix:([NSString stringWithFormat:@"mongodb-realm/%@/%@/%@.realm",
                               self.appId, user.identifier, @"%7B%22%24numberInt%22%3A%22123%22%7D"])]);
    configuration = [user configurationWithPartitionValue:nil];
    XCTAssertTrue([configuration.fileURL.path
                   hasSuffix:([NSString stringWithFormat:@"mongodb-realm/%@/%@/null.realm",
                               self.appId, user.identifier])]);

    XCTAssertEqualObjects([user configurationWithPartitionValue:@"abc"].fileURL.path,
                          newPathForPartitionValue(user, @"abc"));
    XCTAssertEqualObjects([user configurationWithPartitionValue:@123].fileURL.path,
                          newPathForPartitionValue(user, @123));
    XCTAssertEqualObjects([user configurationWithPartitionValue:nil].fileURL.path,
                          newPathForPartitionValue(user, nil));
}

static NSString *oldPathForPartitionValue(LEGACYUser *user, NSString *oldName) {
    realm::SyncConfig config(user._syncUser, "null");
    return [NSString stringWithFormat:@"%@/%s%@.realm",
            [@(user._syncUser->sync_manager()->path_for_realm(config).c_str()) stringByDeletingLastPathComponent],
            user._syncUser->identity().c_str(), oldName];
}

- (void)testLegacyFilePathsAreUsedIfFilesArePresent {
    LEGACYUser *user = self.anonymousUser;

    auto testPartitionValue = [&](id<LEGACYBSON> partitionValue, NSString *oldName) {
        NSURL *url = [NSURL fileURLWithPath:oldPathForPartitionValue(user, oldName)];
        @autoreleasepool {
            auto configuration = [user configurationWithPartitionValue:partitionValue];
            configuration.fileURL = url;
            configuration.objectClasses = @[Person.class];
            LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:configuration error:nil];
            [realm beginWriteTransaction];
            [Person createInRealm:realm withValue:[Person george]];
            [realm commitWriteTransaction];
        }

        auto configuration = [user configurationWithPartitionValue:partitionValue];
        configuration.objectClasses = @[Person.class];
        XCTAssertEqualObjects(configuration.fileURL, url);
        LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:configuration error:nil];
        XCTAssertEqual([Person allObjectsInRealm:realm].count, 1U);
    };

    testPartitionValue(@"abc", @"%2F%2522abc%2522");
    testPartitionValue(@123, @"%2F%257B%2522%24numberInt%2522%253A%2522123%2522%257D");
    testPartitionValue(nil, @"%2Fnull");
}
@end

#endif // TARGET_OS_OSX
