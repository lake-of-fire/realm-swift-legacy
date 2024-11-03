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

/// :nodoc:
@protocol LEGACYInt @end
/// :nodoc:
@protocol LEGACYBool @end
/// :nodoc:
@protocol LEGACYDouble @end
/// :nodoc:
@protocol LEGACYFloat @end
/// :nodoc:
@protocol LEGACYString @end
/// :nodoc:
@protocol LEGACYDate @end
/// :nodoc:
@protocol LEGACYData @end
/// :nodoc:
@protocol LEGACYDecimal128 @end
/// :nodoc:
@protocol LEGACYObjectId @end
/// :nodoc:
@protocol LEGACYUUID @end

/// :nodoc:
@interface NSNumber ()<LEGACYInt, LEGACYBool, LEGACYDouble, LEGACYFloat>
@end

/**
 `LEGACYProperty` instances represent properties managed by a Realm in the context
 of an object schema. Such properties may be persisted to a Realm file or
 computed from other data from the Realm.

 When using Realm, `LEGACYProperty` instances allow performing migrations and
 introspecting the database's schema.

 These property instances map to columns in the core database.
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // not actually immutable, but the public API kinda is
@interface LEGACYProperty : NSObject

#pragma mark - Properties

/**
 The name of the property.
 */
@property (nonatomic, readonly) NSString *name;

/**
 The type of the property.

 @see `LEGACYPropertyType`
 */
@property (nonatomic, readonly) LEGACYPropertyType type;

/**
 Indicates whether this property is indexed.

 @see `LEGACYObject`
 */
@property (nonatomic, readonly) BOOL indexed;

/**
 For `LEGACYObject` and `LEGACYCollection` properties, the name of the class of object stored in the property.
 */
@property (nonatomic, readonly, copy, nullable) NSString *objectClassName;

/**
 For linking objects properties, the property name of the property the linking objects property is linked to.
 */
@property (nonatomic, readonly, copy, nullable) NSString *linkOriginPropertyName;

/**
 Indicates whether this property is optional.
 */
@property (nonatomic, readonly) BOOL optional;

/**
 Indicates whether this property is an array.
 */
@property (nonatomic, readonly) BOOL array;

/**
 Indicates whether this property is a set.
 */
@property (nonatomic, readonly) BOOL set;

/**
 Indicates whether this property is a dictionary.
 */
@property (nonatomic, readonly) BOOL dictionary;

/**
 Indicates whether this property is an array or set.
 */
@property (nonatomic, readonly) BOOL collection;

#pragma mark - Methods

/**
 Returns whether a given property object is equal to the receiver.
 */
- (BOOL)isEqualToProperty:(LEGACYProperty *)property;

@end


/**
 An `LEGACYPropertyDescriptor` instance represents a specific property on a given class.
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL
@interface LEGACYPropertyDescriptor : NSObject

/**
 Creates and returns a property descriptor.

 @param objectClass  The class of this property descriptor.
 @param propertyName The name of this property descriptor.
 */
+ (instancetype)descriptorWithClass:(Class)objectClass propertyName:(NSString *)propertyName;

/// The class of the property.
@property (nonatomic, readonly) Class objectClass;

/// The name of the property.
@property (nonatomic, readonly) NSString *propertyName;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
