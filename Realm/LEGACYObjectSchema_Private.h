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

#import <Realm/LEGACYObjectSchema.h>

#import <objc/runtime.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability)

// LEGACYObjectSchema private
@interface LEGACYObjectSchema () {
@public
    bool _isSwiftClass;
}

/// The object type name reported to the object store and core.
@property (nonatomic, readonly) NSString *objectName;

// writable redeclaration
@property (nonatomic, readwrite, copy) NSArray<LEGACYProperty *> *properties;
@property (nonatomic, readwrite, assign) bool isSwiftClass;
@property (nonatomic, readwrite, assign) BOOL isEmbedded;
@property (nonatomic, readwrite, assign) BOOL isAsymmetric;

// class used for this object schema
@property (nonatomic, readwrite, assign) Class objectClass;
@property (nonatomic, readwrite, assign) Class accessorClass;
@property (nonatomic, readwrite, assign) Class unmanagedClass;

@property (nonatomic, readwrite, assign) bool hasCustomEventSerialization;

@property (nonatomic, readwrite, nullable) LEGACYProperty *primaryKeyProperty;

@property (nonatomic, copy) NSArray<LEGACYProperty *> *computedProperties;
@property (nonatomic, readonly, nullable) NSArray<LEGACYProperty *> *swiftGenericProperties;

// returns a cached or new schema for a given object class
+ (instancetype)schemaForObjectClass:(Class)objectClass;
@end

@interface LEGACYObjectSchema (Dynamic)
/**
 This method is useful only in specialized circumstances, for example, when accessing objects
 in a Realm produced externally. If you are simply building an app on Realm, it is not recommended
 to use this method as an [LEGACYObjectSchema](LEGACYObjectSchema) is generated automatically for every [LEGACYObject](LEGACYObject) subclass.

 Initialize an LEGACYObjectSchema with classname, objectClass, and an array of properties

 @warning This method is useful only in specialized circumstances.

 @param objectClassName     The name of the class used to refer to objects of this type.
 @param objectClass         The Objective-C class used when creating instances of this type.
 @param properties          An array of LEGACYProperty instances describing the managed properties for this type.

 @return    An initialized instance of LEGACYObjectSchema.
 */
- (instancetype)initWithClassName:(NSString *)objectClassName objectClass:(Class)objectClass properties:(NSArray *)properties;
@end

LEGACY_HEADER_AUDIT_END(nullability)
