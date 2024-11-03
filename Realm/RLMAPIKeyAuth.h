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

#import <Realm/LEGACYProviderClient.h>

@class LEGACYUserAPIKey, LEGACYObjectId;

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

/// Provider client for user API keys.
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // immutable final class
@interface LEGACYAPIKeyAuth : LEGACYProviderClient

/// A block type used to report an error
LEGACY_SWIFT_SENDABLE // invoked on a background thread
typedef void(^LEGACYAPIKeyAuthOptionalErrorBlock)(NSError * _Nullable);

/// A block type used to return an `LEGACYUserAPIKey` on success, or an `NSError` on failure
LEGACY_SWIFT_SENDABLE // invoked on a background thread
typedef void(^LEGACYOptionalUserAPIKeyBlock)(LEGACYUserAPIKey * _Nullable, NSError * _Nullable);

/// A block type used to return an array of `LEGACYUserAPIKey` on success, or an `NSError` on failure
LEGACY_SWIFT_SENDABLE // invoked on a background thread
typedef void(^LEGACYUserAPIKeysBlock)(NSArray<LEGACYUserAPIKey *> *  _Nullable, NSError * _Nullable);

/**
  Creates a user API key that can be used to authenticate as the current user.
 
  @param name The name of the API key to be created.
  @param completion A callback to be invoked once the call is complete.
*/
- (void)createAPIKeyWithName:(NSString *)name
                  completion:(LEGACYOptionalUserAPIKeyBlock)completion NS_SWIFT_NAME(createAPIKey(named:completion:));

/**
  Fetches a user API key associated with the current user.
 
  @param objectId The ObjectId of the API key to fetch.
  @param completion A callback to be invoked once the call is complete.
 */
- (void)fetchAPIKey:(LEGACYObjectId *)objectId
         completion:(LEGACYOptionalUserAPIKeyBlock)completion;

/**
  Fetches the user API keys associated with the current user.
 
  @param completion A callback to be invoked once the call is complete.
 */
- (void)fetchAPIKeysWithCompletion:(LEGACYUserAPIKeysBlock)completion;

/**
  Deletes a user API key associated with the current user.
 
  @param objectId The ObjectId of the API key to delete.
  @param completion A callback to be invoked once the call is complete.
 */
- (void)deleteAPIKey:(LEGACYObjectId *)objectId
          completion:(LEGACYAPIKeyAuthOptionalErrorBlock)completion;

/**
  Enables a user API key associated with the current user.
 
  @param objectId The ObjectId of the  API key to enable.
  @param completion A callback to be invoked once the call is complete.
 */
- (void)enableAPIKey:(LEGACYObjectId *)objectId
          completion:(LEGACYAPIKeyAuthOptionalErrorBlock)completion;

/**
  Disables a user API key associated with the current user.
 
  @param objectId The ObjectId of the API key to disable.
  @param completion A callback to be invoked once the call is complete.
 */
- (void)disableAPIKey:(LEGACYObjectId *)objectId
           completion:(LEGACYAPIKeyAuthOptionalErrorBlock)completion;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
