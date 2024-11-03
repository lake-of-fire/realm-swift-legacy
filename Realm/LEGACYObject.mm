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

#import "LEGACYObject_Private.hpp"

#import "LEGACYAccessor.h"
#import "LEGACYArray.h"
#import "LEGACYCollection_Private.hpp"
#import "LEGACYObjectBase_Private.h"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYSchema_Private.h"

#import <realm/object-store/object.hpp>

// We declare things in LEGACYObject which are actually implemented in LEGACYObjectBase
// for documentation's sake, which leads to -Wunimplemented-method warnings.
// Other alternatives to this would be to disable -Wunimplemented-method for this
// file (but then we could miss legitimately missing things), or declaring the
// inherited things in a category (but they currently aren't nicely grouped for
// that).
@implementation LEGACYObject

// synthesized in LEGACYObjectBase
@dynamic invalidated, realm, objectSchema;

#pragma mark - Designated Initializers

- (instancetype)init {
    return [super init];
}

#pragma mark - Convenience Initializers

- (instancetype)initWithValue:(id)value {
    if (!(self = [self init])) {
        return nil;
    }
    LEGACYInitializeWithValue(self, value, LEGACYSchema.partialPrivateSharedSchema);
    return self;
}

#pragma mark - Class-based Object Creation

+ (instancetype)createInDefaultRealmWithValue:(id)value {
    return (LEGACYObject *)LEGACYCreateObjectInRealmWithValue([LEGACYRealm defaultRealm], [self className], value, LEGACYUpdatePolicyError);
}

+ (instancetype)createInRealm:(LEGACYRealm *)realm withValue:(id)value {
    return (LEGACYObject *)LEGACYCreateObjectInRealmWithValue(realm, [self className], value, LEGACYUpdatePolicyError);
}

+ (instancetype)createOrUpdateInDefaultRealmWithValue:(id)value {
    return [self createOrUpdateInRealm:[LEGACYRealm defaultRealm] withValue:value];
}

+ (instancetype)createOrUpdateModifiedInDefaultRealmWithValue:(id)value {
    return [self createOrUpdateModifiedInRealm:[LEGACYRealm defaultRealm] withValue:value];
}

+ (instancetype)createOrUpdateInRealm:(LEGACYRealm *)realm withValue:(id)value {
    LEGACYVerifyHasPrimaryKey(self);
    return (LEGACYObject *)LEGACYCreateObjectInRealmWithValue(realm, [self className], value, LEGACYUpdatePolicyUpdateAll);
}

+ (instancetype)createOrUpdateModifiedInRealm:(LEGACYRealm *)realm withValue:(id)value {
    LEGACYVerifyHasPrimaryKey(self);
    return (LEGACYObject *)LEGACYCreateObjectInRealmWithValue(realm, [self className], value, LEGACYUpdatePolicyUpdateChanged);
}

#pragma mark - Subscripting

- (id)objectForKeyedSubscript:(NSString *)key {
    return LEGACYObjectBaseObjectForKeyedSubscript(self, key);
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key {
    LEGACYObjectBaseSetObjectForKeyedSubscript(self, key, obj);
}

#pragma mark - Getting & Querying

+ (LEGACYResults *)allObjects {
    return LEGACYGetObjects(LEGACYRealm.defaultRealm, self.className, nil);
}

+ (LEGACYResults *)allObjectsInRealm:(__unsafe_unretained LEGACYRealm *const)realm {
    return LEGACYGetObjects(realm, self.className, nil);
}

+ (LEGACYResults *)objectsWhere:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    LEGACYResults *results = [self objectsWhere:predicateFormat args:args];
    va_end(args);
    return results;
}

+ (LEGACYResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args {
    return [self objectsWithPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

+ (LEGACYResults *)objectsInRealm:(LEGACYRealm *)realm where:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    LEGACYResults *results = [self objectsInRealm:realm where:predicateFormat args:args];
    va_end(args);
    return results;
}

+ (LEGACYResults *)objectsInRealm:(LEGACYRealm *)realm where:(NSString *)predicateFormat args:(va_list)args {
    return [self objectsInRealm:realm withPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

+ (LEGACYResults *)objectsWithPredicate:(NSPredicate *)predicate {
    return LEGACYGetObjects(LEGACYRealm.defaultRealm, self.className, predicate);
}

+ (LEGACYResults *)objectsInRealm:(LEGACYRealm *)realm withPredicate:(NSPredicate *)predicate {
    return LEGACYGetObjects(realm, self.className, predicate);
}

+ (instancetype)objectForPrimaryKey:(id)primaryKey {
    return LEGACYGetObject(LEGACYRealm.defaultRealm, self.className, primaryKey);
}

+ (instancetype)objectInRealm:(LEGACYRealm *)realm forPrimaryKey:(id)primaryKey {
    return LEGACYGetObject(realm, self.className, primaryKey);
}

#pragma mark - Other Instance Methods

- (BOOL)isEqualToObject:(LEGACYObject *)object {
    return [object isKindOfClass:LEGACYObject.class] && LEGACYObjectBaseAreEqual(self, object);
}

- (instancetype)freeze {
    return LEGACYObjectFreeze(self);
}

- (instancetype)thaw {
    return LEGACYObjectThaw(self);
}

- (BOOL)isFrozen {
    return _realm.isFrozen;
}

- (LEGACYNotificationToken *)addNotificationBlock:(LEGACYObjectChangeBlock)block {
    return LEGACYObjectAddNotificationBlock(self, block, nil, nil);
}

- (LEGACYNotificationToken *)addNotificationBlock:(LEGACYObjectChangeBlock)block
                                         queue:(nonnull dispatch_queue_t)queue {
    return LEGACYObjectAddNotificationBlock(self, block, nil, queue);
}

- (LEGACYNotificationToken *)addNotificationBlock:(LEGACYObjectChangeBlock)block
                                      keyPaths:(NSArray<NSString *> *)keyPaths {
    return LEGACYObjectAddNotificationBlock(self, block, keyPaths, nil);
}

- (LEGACYNotificationToken *)addNotificationBlock:(LEGACYObjectChangeBlock)block
                                      keyPaths:(NSArray<NSString *> *)keyPaths
                                         queue:(dispatch_queue_t)queue {
    return LEGACYObjectAddNotificationBlock(self, block, keyPaths, queue);

}

+ (NSString *)className {
    return [super className];
}

#pragma mark - Default values for schema definition

+ (NSArray *)indexedProperties {
    return @[];
}

+ (NSDictionary *)linkingObjectsProperties {
    return @{};
}

+ (NSDictionary *)defaultPropertyValues {
    return nil;
}

+ (NSString *)primaryKey {
    return nil;
}

+ (NSArray *)ignoredProperties {
    return nil;
}

+ (NSArray *)requiredProperties {
    return @[];
}

+ (bool)_realmIgnoreClass {
    return false;
}

@end

@implementation LEGACYDynamicObject

+ (bool)_realmIgnoreClass {
    return true;
}

+ (BOOL)shouldIncludeInDefaultSchema {
    return NO;
}

- (id)valueForUndefinedKey:(NSString *)key {
    return LEGACYDynamicGetByName(self, key);
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    LEGACYDynamicValidatedSet(self, key, value);
}

+ (LEGACYObjectSchema *)sharedSchema {
    return nil;
}

@end

BOOL LEGACYIsObjectOrSubclass(Class klass) {
    return LEGACYIsKindOfClass(klass, LEGACYObjectBase.class);
}

BOOL LEGACYIsObjectSubclass(Class klass) {
    return LEGACYIsKindOfClass(class_getSuperclass(class_getSuperclass(klass)), LEGACYObjectBase.class);
}
