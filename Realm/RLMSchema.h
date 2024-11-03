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

#import <Realm/LEGACYConstants.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@class LEGACYObjectSchema;

/**
 `LEGACYSchema` instances represent collections of model object schemas managed by a Realm.

 When using Realm, `LEGACYSchema` instances allow performing migrations and
 introspecting the database's schema.

 Schemas map to collections of tables in the core database.
 */
LEGACY_SWIFT_SENDABLE // not actually immutable, but the public API kinda is
@interface LEGACYSchema : NSObject<NSCopying>

#pragma mark - Properties

/**
 An `NSArray` containing `LEGACYObjectSchema`s for all object types in the Realm.

 This property is intended to be used during migrations for dynamic introspection.

 @see `LEGACYObjectSchema`
 */
@property (nonatomic, readonly, copy) NSArray<LEGACYObjectSchema *> *objectSchema;

#pragma mark - Methods

/**
 Returns an `LEGACYObjectSchema` for the given class name in the schema.

 @param className   The object class name.
 @return            An `LEGACYObjectSchema` for the given class in the schema.

 @see               `LEGACYObjectSchema`
 */
- (nullable LEGACYObjectSchema *)schemaForClassName:(NSString *)className;

/**
 Looks up and returns an `LEGACYObjectSchema` for the given class name in the Realm.

 If there is no object of type `className` in the schema, an exception will be thrown.

 @param className   The object class name.
 @return            An `LEGACYObjectSchema` for the given class in this Realm.

 @see               `LEGACYObjectSchema`
 */
- (LEGACYObjectSchema *)objectForKeyedSubscript:(NSString *)className;

/**
 Returns whether two `LEGACYSchema` instances are equivalent.
 */
- (BOOL)isEqualToSchema:(LEGACYSchema *)schema;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
