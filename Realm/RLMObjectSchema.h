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

@class LEGACYProperty;

/**
 This class represents Realm model object schemas.

 When using Realm, `LEGACYObjectSchema` instances allow performing migrations and
 introspecting the database's schema.

 Object schemas map to tables in the core database.
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // not actually immutable, but the public API kinda is
@interface LEGACYObjectSchema : NSObject<NSCopying>

#pragma mark - Properties

/**
 An array of `LEGACYProperty` instances representing the managed properties of a class described by the schema.

 @see `LEGACYProperty`
 */
@property (nonatomic, readonly, copy) NSArray<LEGACYProperty *> *properties;

/**
 The name of the class the schema describes.
 */
@property (nonatomic, readonly) NSString *className;

/**
 The property which serves as the primary key for the class the schema describes, if any.
 */
@property (nonatomic, readonly, nullable) LEGACYProperty *primaryKeyProperty;

/**
 Whether this object type is embedded.
 */
@property (nonatomic, readonly) BOOL isEmbedded;

/**
 Whether this object is asymmetric.
 */
@property (nonatomic, readonly) BOOL isAsymmetric;

#pragma mark - Methods

/**
 Retrieves an `LEGACYProperty` object by the property name.

 @param propertyName The property's name.

 @return An `LEGACYProperty` object, or `nil` if there is no property with the given name.
 */
- (nullable LEGACYProperty *)objectForKeyedSubscript:(NSString *)propertyName;

/**
 Returns whether two `LEGACYObjectSchema` instances are equal.
 */
- (BOOL)isEqualToObjectSchema:(LEGACYObjectSchema *)objectSchema;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
