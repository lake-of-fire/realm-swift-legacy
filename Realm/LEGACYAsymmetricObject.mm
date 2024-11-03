////////////////////////////////////////////////////////////////////////////
//
// Copyright 2022 Realm Inc.
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

#import "LEGACYAsymmetricObject.h"

#import "LEGACYObject_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYSchema_Private.h"

@implementation LEGACYAsymmetricObject
// synthesized in LEGACYObjectBase but redeclared here for documentation purposes
@dynamic objectSchema;

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

+ (instancetype)createInRealm:(LEGACYRealm *)realm withValue:(id)value {
    LEGACYCreateAsymmetricObjectInRealm(realm, [self className], value);
    return nil;
}

#pragma mark - Subscripting

- (id)objectForKeyedSubscript:(NSString *)key {
    return LEGACYObjectBaseObjectForKeyedSubscript(self, key);
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key {
    LEGACYObjectBaseSetObjectForKeyedSubscript(self, key, obj);
}

#pragma mark - Other Instance Methods

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

+ (bool)isAsymmetric {
    return true;
}
@end
