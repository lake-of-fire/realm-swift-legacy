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

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)
@protocol LEGACYBSON;

/// A token representing an identity provider's credentials.
typedef NSString *LEGACYCredentialsToken;

/// A type representing the unique identifier of an Atlas App Services identity provider.
typedef NSString *LEGACYIdentityProvider NS_EXTENSIBLE_STRING_ENUM;

/// The username/password identity provider. User accounts are handled by Atlas App Services directly without the
/// involvement of a third-party identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderUsernamePassword;

/// A Facebook account as an identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderFacebook;

/// A Google account as an identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderGoogle;

/// An Apple account as an identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderApple;

/// A JSON Web Token as an identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderJWT;

/// An Anonymous account as an identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderAnonymous;

/// An Realm Cloud function as an identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderFunction;

/// A user api key as an identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderUserAPIKey;

/// A server api key as an identity provider.
extern LEGACYIdentityProvider const LEGACYIdentityProviderServerAPIKey;

/**
 Opaque credentials representing a specific Realm App user.
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // immutable final class
@interface LEGACYCredentials : NSObject

/// The name of the identity provider which generated the credentials token.
@property (nonatomic, readonly) LEGACYIdentityProvider provider;

/**
 Construct and return credentials from a Facebook account token.
 */
+ (instancetype)credentialsWithFacebookToken:(LEGACYCredentialsToken)token;

/**
 Construct and return credentials from a Google account token.
 */
+ (instancetype)credentialsWithGoogleAuthCode:(LEGACYCredentialsToken)token;

/**
 Construct and return credentials from a Google id token.
 */
+ (instancetype)credentialsWithGoogleIdToken:(LEGACYCredentialsToken)token;

/**
 Construct and return credentials from an Apple account token.
 */
+ (instancetype)credentialsWithAppleToken:(LEGACYCredentialsToken)token;

/**
 Construct and return credentials for an Atlas App Services function using a mongodb document as a json payload.
*/
+ (instancetype)credentialsWithFunctionPayload:(NSDictionary<NSString *, id<LEGACYBSON>> *)payload;

/**
 Construct and return credentials from a user api key.
*/
+ (instancetype)credentialsWithUserAPIKey:(NSString *)apiKey;

/**
 Construct and return credentials from a server api key.
*/
+ (instancetype)credentialsWithServerAPIKey:(NSString *)apiKey;

/**
 Construct and return Atlas App Services credentials from an email and password.
 */
+ (instancetype)credentialsWithEmail:(NSString *)email
                            password:(NSString *)password;

/**
 Construct and return credentials from a JSON Web Token.
 */
+ (instancetype)credentialsWithJWT:(NSString *)token;

/**
 Construct and return anonymous credentials
 */
+ (instancetype)anonymousCredentials;

/// :nodoc:
- (instancetype)init __attribute__((unavailable("LEGACYAppCredentials cannot be created directly")));

/// :nodoc:
+ (instancetype)new __attribute__((unavailable("LEGACYAppCredentials cannot be created directly")));

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
