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

#import <Realm/LEGACYObjectBase_Dynamic.h>

#import <Realm/LEGACYRealm.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@class LEGACYProperty, LEGACYArray, LEGACYSchema;
typedef NS_ENUM(int32_t, LEGACYPropertyType);

FOUNDATION_EXTERN void LEGACYInitializeWithValue(LEGACYObjectBase *, id, LEGACYSchema *);

typedef void (^LEGACYObjectNotificationCallback)(LEGACYObjectBase *_Nullable object,
                                              NSArray<NSString *> *_Nullable propertyNames,
                                              NSArray *_Nullable oldValues,
                                              NSArray *_Nullable newValues,
                                              NSError *_Nullable error);

// LEGACYObject accessor and read/write realm
@interface LEGACYObjectBase () {
@public
    LEGACYRealm *_realm;
    __unsafe_unretained LEGACYObjectSchema *_objectSchema;
}

// shared schema for this class
+ (nullable LEGACYObjectSchema *)sharedSchema;

+ (nullable NSArray<LEGACYProperty *> *)_getProperties;
+ (bool)_realmIgnoreClass;

// This enables to override the propertiesMapping in Swift, it is not to be used in Objective-C API.
+ (NSDictionary<NSString *, NSString *> *)propertiesMapping;
@end

@interface LEGACYDynamicObject : LEGACYObject

@end

// Calls valueForKey: and re-raises NSUndefinedKeyExceptions
FOUNDATION_EXTERN id _Nullable LEGACYValidatedValueForProperty(id object, NSString *key, NSString *className);

// Compare two RLObjectBases
FOUNDATION_EXTERN BOOL LEGACYObjectBaseAreEqual(LEGACYObjectBase * _Nullable o1, LEGACYObjectBase * _Nullable o2);

FOUNDATION_EXTERN LEGACYNotificationToken *LEGACYObjectBaseAddNotificationBlock(LEGACYObjectBase *obj,
                                                                          NSArray<NSString *> *_Nullable keyPaths,
                                                                          dispatch_queue_t _Nullable queue,
                                                                          LEGACYObjectNotificationCallback block);

LEGACYNotificationToken *LEGACYObjectAddNotificationBlock(LEGACYObjectBase *obj,
                                                    LEGACYObjectChangeBlock block,
                                                    NSArray<NSString *> *_Nullable keyPaths,
                                                    dispatch_queue_t _Nullable queue);

// Returns whether the class is a descendent of LEGACYObjectBase
FOUNDATION_EXTERN BOOL LEGACYIsObjectOrSubclass(Class klass);

// Returns whether the class is an indirect descendant of LEGACYObjectBase
FOUNDATION_EXTERN BOOL LEGACYIsObjectSubclass(Class klass);

FOUNDATION_EXTERN const NSUInteger LEGACYDescriptionMaxDepth;

FOUNDATION_EXTERN id LEGACYObjectFreeze(LEGACYObjectBase *obj) NS_RETURNS_RETAINED;

FOUNDATION_EXTERN id LEGACYObjectThaw(LEGACYObjectBase *obj);

// Gets an object identifier suitable for use with Combine. This value may
// change when an unmanaged object is added to the Realm.
FOUNDATION_EXTERN uint64_t LEGACYObjectBaseGetCombineId(LEGACYObjectBase *);

// An accessor object which is used to interact with Swift properties from obj-c
@interface LEGACYManagedPropertyAccessor : NSObject
// Perform any initialization required for KVO on a *unmanaged* object
+ (void)observe:(LEGACYProperty *)property on:(LEGACYObjectBase *)parent;
// Initialize the given property on a *managed* object which previous was unmanaged
+ (void)promote:(LEGACYProperty *)property on:(LEGACYObjectBase *)parent;
// Initialize the given property on a newly created *managed* object
+ (void)initialize:(LEGACYProperty *)property on:(LEGACYObjectBase *)parent;
// Read the value of the property, on either kind of object
+ (id)get:(LEGACYProperty *)property on:(LEGACYObjectBase *)parent;
// Set the property to the given value, on either kind of object
+ (void)set:(LEGACYProperty *)property on:(LEGACYObjectBase *)parent to:(id)value;
@end

@interface LEGACYObjectNotificationToken : LEGACYNotificationToken
- (void)observe:(LEGACYObjectBase *)obj
       keyPaths:(nullable NSArray<NSString *> *)keyPaths
          block:(LEGACYObjectNotificationCallback)block;
- (void)registrationComplete:(void (^)(void))completion;
@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
