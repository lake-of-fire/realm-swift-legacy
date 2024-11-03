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

#import <Realm/LEGACYConstants.h>
#import <Realm/LEGACYCredentials.h>
#import <Realm/LEGACYRealmConfiguration.h>
#import <Realm/LEGACYSyncConfiguration.h>

@class LEGACYUser, LEGACYSyncSession, LEGACYRealm, LEGACYUserIdentity, LEGACYAPIKeyAuth, LEGACYMongoClient, LEGACYMongoDatabase, LEGACYMongoCollection, LEGACYUserProfile;
@protocol LEGACYBSON;

/**
 The state of the user object.
 */
typedef NS_ENUM(NSUInteger, LEGACYUserState) {
    /// The user is logged out. Call `logInWithCredentials:...` with valid credentials to log the user back in.
    LEGACYUserStateLoggedOut,
    /// The user is logged in, and any Realms associated with it are syncing with Atlas App Services.
    LEGACYUserStateLoggedIn,
    /// The user has been removed, and cannot be used.
    LEGACYUserStateRemoved
};

/// A block type used to report an error related to a specific user.
LEGACY_SWIFT_SENDABLE
typedef void(^LEGACYOptionalUserBlock)(LEGACYUser * _Nullable, NSError * _Nullable);

/// A block type used to report an error on a network request from the user.
LEGACY_SWIFT_SENDABLE
typedef void(^LEGACYUserOptionalErrorBlock)(NSError * _Nullable);

/// A block which returns a dictionary should there be any custom data set for a user
LEGACY_SWIFT_SENDABLE
typedef void(^LEGACYUserCustomDataBlock)(NSDictionary * _Nullable, NSError * _Nullable);

/// A block type for returning from function calls.
LEGACY_SWIFT_SENDABLE
typedef void(^LEGACYCallFunctionCompletionBlock)(id<LEGACYBSON> _Nullable, NSError * _Nullable);

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

/**
 A `LEGACYUser` instance represents a single Realm App user account.

 A user may have one or more credentials associated with it. These credentials
 uniquely identify the user to the authentication provider, and are used to sign
 into an Atlas App Services user account.

 Note that user objects are only vended out via SDK APIs, and cannot be directly
 initialized. User objects can be accessed from any thread.
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // internally thread-safe
@interface LEGACYUser : NSObject

/**
 The unique Atlas App Services string identifying this user.
 Note this is different from an identity: A user may have multiple identities but has a single identifier. See LEGACYUserIdentity.
 */
@property (nonatomic, readonly) NSString *identifier NS_SWIFT_NAME(id);

/// Returns an array of identities currently linked to a user.
@property (nonatomic, readonly) NSArray<LEGACYUserIdentity *> *identities;

/**
 The user's refresh token used to access App Services.

 By default, refresh tokens expire 60 days after they are issued.
 You can configure this time for your App's refresh tokens to be
 anywhere between 30 minutes and 180 days.

 You can configure the refresh token expiration time for all sessions in
 an App from the Admin UI or Admin API.
*/
@property (nullable, nonatomic, readonly) NSString *refreshToken;

/**
 The user's access token used to access App Services.

 This is required to make HTTP requests to Atlas App Services like the Data API or GraphQL.
 It should be treated as sensitive data.

 The Realm SDK automatically manages access tokens and refreshes them
 when they expire.
 */
@property (nullable, nonatomic, readonly) NSString *accessToken;

/**
 The current state of the user.
 */
@property (nonatomic, readonly) LEGACYUserState state;

/**
 Indicates if the user is logged in or not. Returns true if the access token and refresh token are not empty.
 */
@property (nonatomic, readonly) BOOL isLoggedIn;

#pragma mark - Lifecycle

/**
 Create a partition-based sync configuration instance for the given partition value.

 @param partitionValue The `LEGACYBSON` value the Realm is partitioned on.
 @return A default configuration object with the sync configuration set to use the given partition value.
 */
- (LEGACYRealmConfiguration *)configurationWithPartitionValue:(nullable id<LEGACYBSON>)partitionValue NS_REFINED_FOR_SWIFT;

/**
 Create a partition-based sync configuration instance for the given partition value.

 @param partitionValue The `LEGACYBSON` value the Realm is partitioned on.
 @param clientResetMode Determines file recovery behavior in the event of a client reset.
                        See: https://docs.mongodb.com/realm/sync/error-handling/client-resets/
 
 @return A configuration object with the sync configuration set to use the given partition value.
 */
- (LEGACYRealmConfiguration *)configurationWithPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                           clientResetMode:(LEGACYClientResetMode)clientResetMode NS_REFINED_FOR_SWIFT;

/**
 Create a partition-based sync configuration instance for the given partition value.

 @param partitionValue The `LEGACYBSON` value the Realm is partitioned on.
 @param clientResetMode Determines file recovery behavior in the event of a client reset.
                        See: https://docs.mongodb.com/realm/sync/error-handling/client-resets/
 @param beforeResetBlock A callback which notifies prior to a client reset occurring. See: `LEGACYClientResetBeforeBlock`
 @param afterResetBlock A callback which notifies after a client reset has occurred. See: `LEGACYClientResetAfterBlock`
 
 @return A configuration object with the sync configuration set to use the given partition value.
 */
- (LEGACYRealmConfiguration *)configurationWithPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                           clientResetMode:(LEGACYClientResetMode)clientResetMode
                                         notifyBeforeReset:(nullable LEGACYClientResetBeforeBlock)beforeResetBlock
                                          notifyAfterReset:(nullable LEGACYClientResetAfterBlock)afterResetBlock NS_REFINED_FOR_SWIFT;

/**
 Create a partition-based sync configuration instance for the given partition value.

 @param partitionValue The `LEGACYBSON` value the Realm is partitioned on.
 @param clientResetMode Determines file recovery behavior in the event of a client reset.
                        See: https://docs.mongodb.com/realm/sync/error-handling/client-resets/
 @param manualClientResetHandler An error reporting block that is invoked during a client reset.
                                @See ``LEGACYSyncErrorReportingBlock`` and ``LEGACYClientResetInfo``
 
 @return A configuration object with the sync configuration set to use the given partition value.
 */
- (LEGACYRealmConfiguration *)configurationWithPartitionValue:(nullable id<LEGACYBSON>)partitionValue
                                           clientResetMode:(LEGACYClientResetMode)clientResetMode
                                  manualClientResetHandler:(nullable LEGACYSyncErrorReportingBlock)manualClientResetHandler NS_REFINED_FOR_SWIFT;

/**
 Create a flexible sync configuration instance, which can be used to open a Realm that
 supports flexible sync.
 
 @note A single server-side Device Sync App can sync data with either partition-based realms or flexible sync based realms.
 In order for an application to contain both partition-based and flexible sync realms, more than one
 server-side Device Sync App must be used.

 @return A ``LEGACYRealmConfiguration`` instance with a flexible sync configuration.
 */
- (LEGACYRealmConfiguration *)flexibleSyncConfiguration NS_REFINED_FOR_SWIFT;

/**
 Create a flexible sync configuration instance, which can be used to open a Realm that
 supports flexible sync.
 
 @note A single server-side Device Sync App can sync data with either partition-based realms or flexible sync based realms.
 In order for an application to contain both partition-based and flexible sync realms, more than one
 server-side Device Sync App must be used.
 
 @param clientResetMode Determines file recovery behavior in the event of a client reset.
                        See: https://docs.mongodb.com/realm/sync/error-handling/client-resets/
 @param beforeResetBlock A callback which notifies prior to a client reset occurring. See: `LEGACYClientResetBeforeBlock`
 @param afterResetBlock A callback which notifies after a client reset has occurred. See: `LEGACYClientResetAfterBlock`
 
 @return A `LEGACYRealmConfiguration` instance with a flexible sync configuration.
 */
- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithClientResetMode:(LEGACYClientResetMode)clientResetMode
                                                      notifyBeforeReset:(nullable LEGACYClientResetBeforeBlock)beforeResetBlock
                                                       notifyAfterReset:(nullable LEGACYClientResetAfterBlock)afterResetBlock NS_REFINED_FOR_SWIFT;
/**
 Create a flexible sync configuration instance, which can be used to open a Realm that
 supports flexible sync.

 @note A single server-side Device Sync App can sync data with either partition-based realms or flexible sync based realms.
 In order for an application to contain both partition-based and flexible sync realms, more than one
 server-side Device Sync App must be used.

 @param clientResetMode Determines file recovery behavior in the event of a client reset.
                        See: https://docs.mongodb.com/realm/sync/error-handling/client-resets/
 @param manualClientResetHandler An error reporting block that is invoked during a client reset.
                                @See `LEGACYSyncErrorReportingBlock` and `LEGACYClientResetInfo`

 @return A `LEGACYRealmConfiguration` instance with a flexible sync configuration.
 */
- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithClientResetMode:(LEGACYClientResetMode)clientResetMode
                                               manualClientResetHandler:(nullable LEGACYSyncErrorReportingBlock)manualClientResetHandler NS_REFINED_FOR_SWIFT;

/**
 Create a flexible sync configuration instance, which can be used to open a Realm that
 supports flexible sync.

 @note A single server-side Device Sync App can sync data with either partition-based realms or flexible sync based realms.
 In order for an application to contain both partition-based and flexible sync realms, more than one
 server-side Device Sync App must be used.

 @param initialSubscriptions A block which receives a subscription set instance, that can be
                             used to add an initial set of subscriptions which will be executed
                             when the Realm is first opened.
 @param rerunOnOpen If true, allows to run the initial set of subscriptions specified, on every app startup.
                    This can be used to re-run dynamic time ranges and other queries that require a
                    re-computation of a static variable.

 @return A `LEGACYRealmConfiguration` instance with a flexible sync configuration.
 */
- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithInitialSubscriptions:(LEGACYFlexibleSyncInitialSubscriptionsBlock)initialSubscriptions
                                                                 rerunOnOpen:(BOOL)rerunOnOpen NS_REFINED_FOR_SWIFT;
/**
 Create a flexible sync configuration instance, which can be used to open a Realm that
 supports flexible sync.

 @note A single server-side Device Sync App can sync data with either partition-based realms or flexible sync based realms.
 In order for an application to contain both partition-based and flexible sync realms, more than one
 server-side Device Sync App must be used.

 @param initialSubscriptions A block which receives a subscription set instance, that can be
                             used to add an initial set of subscriptions which will be executed
                             when the Realm is first opened.
 @param rerunOnOpen If true, allows to run the initial set of subscriptions specified, on every app startup.
                    This can be used to re-run dynamic time ranges and other queries that require a
                    re-computation of a static variable.
 @param clientResetMode Determines file recovery behavior in the event of a client reset.
                        See: https://docs.mongodb.com/realm/sync/error-handling/client-resets/
 @param beforeResetBlock A callback which notifies prior to a client reset occurring. See: `LEGACYClientResetBeforeBlock`
 @param afterResetBlock A callback which notifies after a client reset has occurred. See: `LEGACYClientResetAfterBlock`

 @return A `LEGACYRealmConfiguration` instance with a flexible sync configuration.
 */
- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithInitialSubscriptions:(LEGACYFlexibleSyncInitialSubscriptionsBlock)initialSubscriptions
                                                                 rerunOnOpen:(BOOL)rerunOnOpen
                                                             clientResetMode:(LEGACYClientResetMode)clientResetMode
                                                           notifyBeforeReset:(nullable LEGACYClientResetBeforeBlock)beforeResetBlock
                                                            notifyAfterReset:(nullable LEGACYClientResetAfterBlock)afterResetBlock NS_REFINED_FOR_SWIFT;

/**
 Create a flexible sync configuration instance, which can be used to open a Realm that
 supports flexible sync.

 @note A single server-side Device Sync App can sync data with either partition-based realms or flexible sync based realms.
 In order for an application to contain both partition-based and flexible sync realms, more than one
 server-side Device Sync App must be used.

 @param initialSubscriptions A block which receives a subscription set instance, that can be
                             used to add an initial set of subscriptions which will be executed
                             when the Realm is first opened.
 @param rerunOnOpen If true, allows to run the initial set of subscriptions specified, on every app startup.
                    This can be used to re-run dynamic time ranges and other queries that require a
                    re-computation of a static variable.
 @param clientResetMode Determines file recovery behavior in the event of a client reset.
                        See: https://docs.mongodb.com/realm/sync/error-handling/client-resets/
 @param manualClientResetHandler An error reporting block that is invoked during a client reset.
                                @See `LEGACYSyncErrorReportingBlock` and `LEGACYClientResetInfo`

 @return A `LEGACYRealmConfiguration` instance with a flexible sync configuration.
 */
- (LEGACYRealmConfiguration *)flexibleSyncConfigurationWithInitialSubscriptions:(LEGACYFlexibleSyncInitialSubscriptionsBlock)initialSubscriptions
                                                                 rerunOnOpen:(BOOL)rerunOnOpen
                                                             clientResetMode:(LEGACYClientResetMode)clientResetMode
                                                    manualClientResetHandler:(nullable LEGACYSyncErrorReportingBlock)manualClientResetHandler NS_REFINED_FOR_SWIFT;

#pragma mark - Sessions

/**
 Retrieve a valid session object belonging to this user for a given URL, or `nil`
 if no such object exists.
 */
- (nullable LEGACYSyncSession *)sessionForPartitionValue:(id<LEGACYBSON>)partitionValue;

/// Retrieve all the valid sessions belonging to this user.
@property (nonatomic, readonly) NSArray<LEGACYSyncSession *> *allSessions;

#pragma mark - Custom Data

/**
 The custom data of the user.
 This is configured in your Atlas App Services app.
 */
@property (nonatomic, readonly) NSDictionary *customData NS_REFINED_FOR_SWIFT;

/**
 The profile of the user.
 */
@property (nonatomic, readonly) LEGACYUserProfile *profile;

/**
 Refresh a user's custom data. This will, in effect, refresh the user's auth session.
 */
- (void)refreshCustomDataWithCompletion:(LEGACYUserCustomDataBlock)completion;

/**
 Links the currently authenticated user with a new identity, where the identity is defined by the credential
 specified as a parameter. This will only be successful if this `LEGACYUser` is the currently authenticated
 with the client from which it was created. On success a new user will be returned with the new linked credentials.

 @param credentials The `LEGACYCredentials` used to link the user to a new identity.
 @param completion The completion handler to call when the linking is complete.
                   If the operation is  successful, the result will contain a new
                   `LEGACYUser` object representing the currently logged in user.
*/
- (void)linkUserWithCredentials:(LEGACYCredentials *)credentials
                     completion:(LEGACYOptionalUserBlock)completion NS_REFINED_FOR_SWIFT;

/**
 Removes the user

 This logs out and destroys the session related to this user. The completion block will return an error
 if the user is not found or is already removed.

 @param completion A callback invoked on completion
*/
- (void)removeWithCompletion:(LEGACYUserOptionalErrorBlock)completion;

/**
 Permanently deletes this user from your Atlas App Services app.

 The users state will be set to `Removed` and the session will be destroyed.
 If the delete request fails, the local authentication state will be untouched.

 @param completion A callback invoked on completion
*/
- (void)deleteWithCompletion:(LEGACYUserOptionalErrorBlock)completion;

/**
 Logs out the current user

 The users state will be set to `Removed` is they are an anonymous user or `LoggedOut` if they are authenticated by an email / password or third party auth clients
 If the logout request fails, this method will still clear local authentication state.

 @param completion A callback invoked on completion
*/
- (void)logOutWithCompletion:(LEGACYUserOptionalErrorBlock)completion;

/**
  A client for the user API key authentication provider which
  can be used to create and modify user API keys.

  This client should only be used by an authenticated user.
*/
@property (nonatomic, readonly) LEGACYAPIKeyAuth *apiKeysAuth;

/// A client for interacting with a remote MongoDB instance
/// @param serviceName The name of the MongoDB service
- (LEGACYMongoClient *)mongoClientWithServiceName:(NSString *)serviceName NS_REFINED_FOR_SWIFT;

/**
 Calls the Atlas App Services function with the provided name and arguments.

 @param name The name of the Atlas App Services function to be called.
 @param arguments The `BSONArray` of arguments to be provided to the function.
 @param completion The completion handler to call when the function call is complete.
 This handler is executed on a non-main global `DispatchQueue`.
*/
- (void)callFunctionNamed:(NSString *)name
                arguments:(NSArray<id<LEGACYBSON>> *)arguments
          completionBlock:(LEGACYCallFunctionCompletionBlock)completion NS_REFINED_FOR_SWIFT;

/// :nodoc:
- (instancetype)init __attribute__((unavailable("LEGACYUser cannot be created directly")));
/// :nodoc:
+ (instancetype)new __attribute__((unavailable("LEGACYUser cannot be created directly")));

@end

#pragma mark - User info classes

/**
 An identity of a user. A user can have multiple identities, usually associated with multiple providers.
 Note this is different from a user's unique identifier string.
 @seeAlso `LEGACYUser.identifier`
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // immutable final class
@interface LEGACYUserIdentity : NSObject

/**
 The associated provider type
 */
@property (nonatomic, readonly) NSString *providerType;

/**
 The string which identifies the LEGACYUserIdentity
 */
@property (nonatomic, readonly) NSString *identifier;

/**
 Initialize an LEGACYUserIdentity for the given identifier and provider type.
 @param providerType the associated provider type
 @param identifier the identifier of the identity
 */
- (instancetype)initUserIdentityWithProviderType:(NSString *)providerType
                                      identifier:(NSString *)identifier;

@end

/**
 A profile for a given User.
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // immutable final class
@interface LEGACYUserProfile : NSObject

/// The full name of the user.
@property (nonatomic, readonly, nullable) NSString *name;
/// The email address of the user.
@property (nonatomic, readonly, nullable) NSString *email;
/// A URL to the user's profile picture.
@property (nonatomic, readonly, nullable) NSString *pictureURL;
/// The first name of the user.
@property (nonatomic, readonly, nullable) NSString *firstName;
/// The last name of the user.
@property (nonatomic, readonly, nullable) NSString *lastName;
/// The gender of the user.
@property (nonatomic, readonly, nullable) NSString *gender;
/// The birthdate of the user.
@property (nonatomic, readonly, nullable) NSString *birthday;
/// The minimum age of the user.
@property (nonatomic, readonly, nullable) NSString *minAge;
/// The maximum age of the user.
@property (nonatomic, readonly, nullable) NSString *maxAge;
/// The BSON dictionary of metadata associated with this user.
@property (nonatomic, readonly) NSDictionary *metadata NS_REFINED_FOR_SWIFT;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
