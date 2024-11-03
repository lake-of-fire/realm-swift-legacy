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

#import "LEGACYEmbeddedObject.h"

#import "LEGACYObject_Private.hpp"
#import "LEGACYSchema_Private.h"

@implementation LEGACYEmbeddedObject
// synthesized in LEGACYObjectBase but redeclared here for documentation purposes
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

#pragma mark - Subscripting

- (id)objectForKeyedSubscript:(NSString *)key {
    return LEGACYObjectBaseObjectForKeyedSubscript(self, key);
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key {
    LEGACYObjectBaseSetObjectForKeyedSubscript(self, key, obj);
}

#pragma mark - Other Instance Methods

- (BOOL)isEqualToObject:(LEGACYObjectBase *)object {
    return [object isKindOfClass:LEGACYObjectBase.class] && LEGACYObjectBaseAreEqual(self, object);
}

- (instancetype)freeze {
    return LEGACYObjectFreeze(self);
}

- (instancetype)thaw {
    return LEGACYObjectThaw(self);
}

- (LEGACYNotificationToken *)addNotificationBlock:(LEGACYObjectChangeBlock)block {
    return LEGACYObjectAddNotificationBlock(self, block, nil, nil);
}

- (LEGACYNotificationToken *)addNotificationBlock:(LEGACYObjectChangeBlock)block queue:(dispatch_queue_t)queue {
    return LEGACYObjectAddNotificationBlock(self, block, nil, queue);
}

- (LEGACYNotificationToken *)addNotificationBlock:(LEGACYObjectChangeBlock)block keyPaths:(NSArray<NSString *> *)keyPaths {
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

+ (NSString *)primaryKey {
    return nil;
}

+ (NSArray *)indexedProperties {
    return @[];
}

+ (NSDictionary *)linkingObjectsProperties {
    return @{};
}

+ (NSDictionary *)defaultPropertyValues {
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

+ (bool)isEmbedded {
    return true;
}
@end
