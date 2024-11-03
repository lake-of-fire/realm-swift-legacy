////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
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

#import <Realm/LEGACYObject.h>

@class LEGACYObjectSchema, LEGACYRealm;

LEGACY_HEADER_AUDIT_BEGIN(nullability)

/**
 Returns the Realm that manages the object, if one exists.

 @warning  This function is useful only in specialized circumstances, for example, when building components
           that integrate with Realm. If you are simply building an app on Realm, it is
           recommended to retrieve the Realm that manages the object via `LEGACYObject`.

 @param object	An `LEGACYObjectBase` obtained via a Swift `Object` or `LEGACYObject`.

 @return The Realm which manages this object. Returns `nil `for unmanaged objects.
 */
FOUNDATION_EXTERN LEGACYRealm * _Nullable LEGACYObjectBaseRealm(LEGACYObjectBase * _Nullable object);

/**
 Returns an `LEGACYObjectSchema` which describes the managed properties of the object.

 @warning  This function is useful only in specialized circumstances, for example, when building components
           that integrate with Realm. If you are simply building an app on Realm, it is
           recommended to retrieve `objectSchema` via `LEGACYObject`.

 @param object	An `LEGACYObjectBase` obtained via a Swift `Object` or `LEGACYObject`.

 @return The object schema which lists the managed properties for the object.
 */
FOUNDATION_EXTERN LEGACYObjectSchema * _Nullable LEGACYObjectBaseObjectSchema(LEGACYObjectBase * _Nullable object);

/**
 Returns the object corresponding to a key value.

 @warning  This function is useful only in specialized circumstances, for example, when building components
           that integrate with Realm. If you are simply building an app on Realm, it is
           recommended to retrieve key values via `LEGACYObject`.

 @warning Will throw an `NSUndefinedKeyException` if `key` is not present on the object.

 @param object	An `LEGACYObjectBase` obtained via a Swift `Object` or `LEGACYObject`.
 @param key		The name of the property.

 @return The object for the property requested.
 */
FOUNDATION_EXTERN id _Nullable LEGACYObjectBaseObjectForKeyedSubscript(LEGACYObjectBase * _Nullable object, NSString *key);

/**
 Sets a value for a key on the object.

 @warning  This function is useful only in specialized circumstances, for example, when building components
           that integrate with Realm. If you are simply building an app on Realm, it is
           recommended to set key values via `LEGACYObject`.

 @warning Will throw an `NSUndefinedKeyException` if `key` is not present on the object.

 @param object	An `LEGACYObjectBase` obtained via a Swift `Object` or `LEGACYObject`.
 @param key		The name of the property.
 @param obj		The object to set as the value of the key.
 */
FOUNDATION_EXTERN void LEGACYObjectBaseSetObjectForKeyedSubscript(LEGACYObjectBase * _Nullable object, NSString *key, id _Nullable obj);

LEGACY_HEADER_AUDIT_END(nullability)
