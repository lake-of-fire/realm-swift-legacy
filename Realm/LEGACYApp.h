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

#import <Realm/LEGACYConstants.h>
#import <AuthenticationServices/AuthenticationServices.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@protocol LEGACYNetworkTransport, LEGACYBSON;

@class LEGACYUser, LEGACYCredentials, LEGACYSyncManager, LEGACYEmailPasswordAuth, LEGACYPushClient, LEGACYSyncTimeoutOptions;

/// A block type used for APIs which asynchronously vend an `LEGACYUser`.
typedef void(^LEGACYUserCompletionBlock)(LEGACYUser * _Nullable, NSError * _Nullable);

/// A block type used to report an error
typedef void(^LEGACYOptionalErrorBlock)(NSError * _Nullable);

#pragma mark LEGACYAppConfiguration

/// Properties representing the configuration of a client
/// that communicate with a particular Realm application.
///
/// `LEGACYAppConfiguration` options cannot be modified once the `LEGACYApp` using it
/// is created. App's configuration values are cached when the App is created so any modifications after it
/// will not have any effect.
@interface LEGACYAppConfiguration : NSObject <NSCopying>

/// A custom base URL to request against.
@property (nonatomic, strong, nullable) NSString *baseURL;

/// The custom transport for network calls to the server.
@property (nonatomic, strong, nullable) id<LEGACYNetworkTransport> transport;

/// :nodoc:
@property (nonatomic, strong, nullable) NSString *localAppName
    __attribute__((deprecated("This field is not used")));
/// :nodoc:
@property (nonatomic, strong, nullable) NSString *localAppVersion
    __attribute__((deprecated("This field is not used")));

/// The default timeout for network requests.
@property (nonatomic, assign) NSUInteger defaultRequestTimeoutMS;

/// If enabled (the default), a single connection is used for all Realms opened
/// with a single sync user. If disabled, a separate connection is used for each
/// Realm.
///
/// Session multiplexing reduces resources used and typically improves
/// performance. When multiplexing is enabled, the connection is not immediately
/// closed when the last session is closed, and instead remains open for
/// ``LEGACYSyncTimeoutOptions.connectionLingerTime`` milliseconds (30 seconds by
/// default).
@property (nonatomic, assign) BOOL enableSessionMultiplexing;

/**
 Options for the assorted types of connection timeouts for sync connections.

 If nil default values for all timeouts are used instead.
 */
@property (nonatomic, nullable, copy) LEGACYSyncTimeoutOptions *syncTimeouts;

/// :nodoc:
- (instancetype)initWithBaseURL:(nullable NSString *)baseURL
                      transport:(nullable id<LEGACYNetworkTransport>)transport
                   localAppName:(nullable NSString *)localAppName
                localAppVersion:(nullable NSString *)localAppVersion
__attribute__((deprecated("localAppName and localAppVersion are unused")));

/// :nodoc:
- (instancetype)initWithBaseURL:(nullable NSString *) baseURL
                      transport:(nullable id<LEGACYNetworkTransport>)transport
                   localAppName:(nullable NSString *)localAppName
                localAppVersion:(nullable NSString *)localAppVersion
        defaultRequestTimeoutMS:(NSUInteger)defaultRequestTimeoutMS
__attribute__((deprecated("localAppName and localAppVersion are unused")));

/**
Create a new Realm App configuration.

@param baseURL A custom base URL to request against.
@param transport A custom network transport.
*/
- (instancetype)initWithBaseURL:(nullable NSString *)baseURL
                      transport:(nullable id<LEGACYNetworkTransport>)transport;

/**
 Create a new Realm App configuration.

 @param baseURL A custom base URL to request against.
 @param transport A custom network transport.
 @param defaultRequestTimeoutMS A custom default timeout for network requests.
 */
- (instancetype)initWithBaseURL:(nullable NSString *) baseURL
                      transport:(nullable id<LEGACYNetworkTransport>)transport
        defaultRequestTimeoutMS:(NSUInteger)defaultRequestTimeoutMS;

@end

#pragma mark LEGACYApp

/**
 The `LEGACYApp` has the fundamental set of methods for communicating with a Realm
 application backend.

 This interface provides access to login and authentication.
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // internally thread-safe
@interface LEGACYApp : NSObject

/// The configuration for this Realm app.
@property (nonatomic, readonly) LEGACYAppConfiguration *configuration;

/// The `LEGACYSyncManager` for this Realm app.
@property (nonatomic, readonly) LEGACYSyncManager *syncManager;

/// Get a dictionary containing all users keyed on id.
@property (nonatomic, readonly) NSDictionary<NSString *, LEGACYUser *> *allUsers;

/// Get the current user logged into the Realm app.
@property (nonatomic, readonly, nullable) LEGACYUser *currentUser;

/// The app ID for this Realm app.
@property (nonatomic, readonly) NSString *appId;

/**
  A client for the email/password authentication provider which
  can be used to obtain a credential for logging in.

  Used to perform requests specifically related to the email/password provider.
*/
@property (nonatomic, readonly) LEGACYEmailPasswordAuth *emailPasswordAuth;

/**
 Get an application with a given appId and configuration.

 @param appId The unique identifier of your Realm app.
 */
+ (instancetype)appWithId:(NSString *)appId;

/**
 Get an application with a given appId and configuration.

 @param appId The unique identifier of your Realm app.
 @param configuration A configuration object to configure this client.
 */
+ (instancetype)appWithId:(NSString *)appId
            configuration:(nullable LEGACYAppConfiguration *)configuration;

/**
 Login to a user for the Realm app.

 @param credentials The credentials identifying the user.
 @param completion A callback invoked after completion.
 */
- (void)loginWithCredential:(LEGACYCredentials *)credentials
                 completion:(LEGACYUserCompletionBlock)completion NS_REFINED_FOR_SWIFT;

/**
 Switches the active user to the specified user.

 This sets which user is used by all LEGACYApp operations which require a user. This is a local operation which does not access the network.
 An exception will be throw if the user is not valid. The current user will remain logged in.
 
 @param syncUser The user to switch to.
 @returns The user you intend to switch to
 */
- (LEGACYUser *)switchToUser:(LEGACYUser *)syncUser;

/**
 A client which can be used to register devices with the server to receive push notificatons
 */
- (LEGACYPushClient *)pushClientWithServiceName:(NSString *)serviceName
    NS_SWIFT_NAME(pushClient(serviceName:));

/**
 LEGACYApp instances are cached internally by Realm and cannot be created directly.

 Use `+[LEGACYRealm appWithId]` or `+[LEGACYRealm appWithId:configuration:]`
 to obtain a reference to an LEGACYApp.
 */
- (instancetype)init __attribute__((unavailable("Use +appWithId or appWithId:configuration:.")));

/**
LEGACYApp instances are cached internally by Realm and cannot be created directly.

Use `+[LEGACYRealm appWithId]` or `+[LEGACYRealm appWithId:configuration:]`
to obtain a reference to an LEGACYApp.
*/
+ (instancetype)new __attribute__((unavailable("Use +appWithId or appWithId:configuration:.")));

@end

#pragma mark - Sign In With Apple Extension

API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0))
/// Use this delegate to be provided a callback once authentication has succeed or failed
@protocol LEGACYASLoginDelegate

/// Callback that is invoked should the authentication fail.
/// @param error An error describing the authentication failure.
- (void)authenticationDidFailWithError:(NSError *)error NS_SWIFT_NAME(authenticationDidComplete(error:));

/// Callback that is invoked should the authentication succeed.
/// @param user The newly authenticated user.
- (void)authenticationDidCompleteWithUser:(LEGACYUser *)user NS_SWIFT_NAME(authenticationDidComplete(user:));

@end

API_AVAILABLE(ios(13.0), macos(10.15), tvos(13.0), watchos(6.0))
/// Category extension that deals with Sign In With Apple authentication.
/// This is only available on OS's that support `AuthenticationServices`
@interface LEGACYApp (ASLogin)

/// Use this delegate to be provided a callback once authentication has succeed or failed.
@property (nonatomic, weak, nullable) id<LEGACYASLoginDelegate> authorizationDelegate;

/// Sets the ASAuthorizationControllerDelegate to be handled by `LEGACYApp`
/// @param controller The ASAuthorizationController in which you want `LEGACYApp` to consume its delegate.
- (void)setASAuthorizationControllerDelegateForController:(ASAuthorizationController *)controller NS_REFINED_FOR_SWIFT;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
