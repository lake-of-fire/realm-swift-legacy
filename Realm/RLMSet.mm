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

#import "LEGACYSet_Private.hpp"

#import "LEGACYObjectSchema.h"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.h"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYSchema_Private.h"
#import "LEGACYSwiftSupport.h"
#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUtil.hpp"

@interface LEGACYSet () <LEGACYThreadConfined_Private>
@end

@implementation LEGACYSet {
@public
    // Backing set when this instance is unmanaged
    NSMutableOrderedSet *_backingCollection;
}

#pragma mark - Initializers

- (instancetype)initWithObjectClassName:(__unsafe_unretained NSString *const)objectClassName
                                keyType:(__unused LEGACYPropertyType)keyType {
    return [self initWithObjectClassName:objectClassName];
}
- (instancetype)initWithObjectType:(LEGACYPropertyType)type
                          optional:(BOOL)optional
                           keyType:(__unused LEGACYPropertyType)keyType {
    return [self initWithObjectType:type optional:optional];
}

- (instancetype)initWithObjectClassName:(__unsafe_unretained NSString *const)objectClassName {
    REALM_ASSERT([objectClassName length] > 0);
    self = [super init];
    if (self) {
        _objectClassName = objectClassName;
        _type = LEGACYPropertyTypeObject;
    }
    return self;
}

- (instancetype)initWithObjectType:(LEGACYPropertyType)type optional:(BOOL)optional {
    self = [super init];
    if (self) {
        _type = type;
        _optional = optional;
    }
    return self;
}

- (void)setParent:(LEGACYObjectBase *)parentObject property:(LEGACYProperty *)property {
    _parentObject = parentObject;
    _key = property.name;
    _isLegacyProperty = property.isLegacy;
}

#pragma mark - Convenience wrappers used for all LEGACYSet types

- (void)addObjects:(id<NSFastEnumeration>)objects {
    for (id obj in objects) {
        [self addObject:obj];
    }
}

- (void)addObject:(id)object {
    LEGACYSetValidateMatchingObjectType(self, object);
    changeSet(self, ^{
        [_backingCollection addObject:object];
    });
}

- (void)setObject:(id)newValue atIndexedSubscript:(NSUInteger)index {
    REALM_TERMINATE("Replacing objects at an indexed subscript is not supported on LEGACYSet");
}

- (void)setSet:(LEGACYSet<id> *)set {
    for (id obj in set) {
        LEGACYSetValidateMatchingObjectType(self, obj);
    }
    changeSet(self, ^{
        [_backingCollection removeAllObjects];
        [_backingCollection unionOrderedSet:set->_backingCollection];
    });
}

- (void)intersectSet:(LEGACYSet<id> *)set {
    for (id obj in set) {
        LEGACYSetValidateMatchingObjectType(self, obj);
    }
    changeSet(self, ^{
        [_backingCollection intersectOrderedSet:set->_backingCollection];
    });
}

- (void)minusSet:(LEGACYSet<id> *)set {
    for (id obj in set) {
        LEGACYSetValidateMatchingObjectType(self, obj);
    }
    changeSet(self, ^{
        [_backingCollection minusOrderedSet:set->_backingCollection];
    });
}

- (void)unionSet:(LEGACYSet<id> *)set {
    for (id obj in set) {
        LEGACYSetValidateMatchingObjectType(self, obj);
    }
    changeSet(self, ^{
        [_backingCollection unionOrderedSet:set->_backingCollection];
    });
}

- (BOOL)isSubsetOfSet:(LEGACYSet<id> *)set {
    for (id obj in set) {
        LEGACYSetValidateMatchingObjectType(self, obj);
    }
    return [_backingCollection isSubsetOfOrderedSet:set->_backingCollection];
}

- (BOOL)intersectsSet:(LEGACYSet<id> *)set {
    for (id obj in set) {
        LEGACYSetValidateMatchingObjectType(self, obj);
    }
    return [_backingCollection intersectsOrderedSet:set->_backingCollection];
}

- (BOOL)containsObject:(id)obj {
    LEGACYSetValidateMatchingObjectType(self, obj);
    return [_backingCollection containsObject:obj];
}

- (BOOL)isEqualToSet:(LEGACYSet<id> *)set {
    return [self isEqual:set];
}

- (LEGACYResults *)sortedResultsUsingKeyPath:(NSString *)keyPath ascending:(BOOL)ascending {
    return [self sortedResultsUsingDescriptors:@[[LEGACYSortDescriptor sortDescriptorWithKeyPath:keyPath ascending:ascending]]];
}

- (nonnull id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYArray *, LEGACYCollectionChange *, NSError *))block {
    return LEGACYAddNotificationBlock(self, block, nil, nil);
}
- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYArray *, LEGACYCollectionChange *, NSError *))block
                                         queue:(dispatch_queue_t)queue {
    return LEGACYAddNotificationBlock(self, block, nil, queue);
}

- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYArray *, LEGACYCollectionChange *, NSError *))block
                                      keyPaths:(NSArray<NSString *> *)keyPaths {
    return LEGACYAddNotificationBlock(self, block, keyPaths,nil);
}

- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYArray *, LEGACYCollectionChange *, NSError *))block
                                      keyPaths:(NSArray<NSString *> *)keyPaths
                                         queue:(dispatch_queue_t)queue {
    return LEGACYAddNotificationBlock(self, block, keyPaths, queue);
}
#pragma clang diagnostic pop

#pragma mark - Unmanaged LEGACYSet implementation

- (LEGACYRealm *)realm {
    return nil;
}

- (NSUInteger)count {
    return _backingCollection.count;
}

- (NSArray<id> *)allObjects {
    return _backingCollection.array;
}

// For use with MutableSet subscripting, NSSet does not support
// subscripting while its Swift counterpart `Set` does.
- (id)objectAtIndex:(NSUInteger)index {
    validateSetBounds(self, index);
    return _backingCollection[index];
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes {
    if ([indexes indexGreaterThanOrEqualToIndex:self.count] != NSNotFound) {
        return nil;
    }
    return [_backingCollection objectsAtIndexes:indexes] ?: @[];
}

- (id)firstObject {
    return _backingCollection.firstObject;
}

- (id)lastObject {
    return _backingCollection.lastObject;
}

- (BOOL)isInvalidated {
    return NO;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(__unused NSUInteger)len {
    return LEGACYUnmanagedFastEnumerate(_backingCollection, state);
}

static void changeSet(__unsafe_unretained LEGACYSet *const set,
                      dispatch_block_t f) {
    if (!set->_backingCollection) {
        set->_backingCollection = [NSMutableOrderedSet new];
    }

    if (LEGACYObjectBase *parent = set->_parentObject) {
        [parent willChangeValueForKey:set->_key];
        f();
        [parent didChangeValueForKey:set->_key];
    }
    else {
        f();
    }
}

static void validateSetBounds(__unsafe_unretained LEGACYSet *const set,
                              NSUInteger index,
                              bool allowOnePastEnd=false) {
    NSUInteger max = set->_backingCollection.count + allowOnePastEnd;
    if (index >= max) {
        @throw LEGACYException(@"Index %llu is out of bounds (must be less than %llu).",
                            (unsigned long long)index, (unsigned long long)max);
    }
}

- (void)removeAllObjects {
    changeSet(self, ^{
        [_backingCollection removeAllObjects];
    });
}

- (void)removeObject:(id)object {
    LEGACYSetValidateMatchingObjectType(self, object);
    changeSet(self, ^{
        [_backingCollection removeObject:object];
    });
}

- (void)replaceAllObjectsWithObjects:(NSArray *)objects {
    changeSet(self, ^{
        [_backingCollection removeAllObjects];
        if (!objects || (id)objects == NSNull.null) {
            return;
        }
        for (id object in objects) {
            [_backingCollection addObject:object];
        }
    });
}

- (LEGACYResults *)objectsWhere:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    LEGACYResults *results = [self objectsWhere:predicateFormat args:args];
    va_end(args);
    return results;
}

- (LEGACYResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args {
    return [self objectsWithPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (LEGACYPropertyType)typeForProperty:(NSString *)propertyName {
    if ([propertyName isEqualToString:@"self"]) {
        return _type;
    }

    LEGACYObjectSchema *objectSchema;
    if (_backingCollection.count) {
        objectSchema = [_backingCollection[0] objectSchema];
    }
    else {
        objectSchema = [LEGACYSchema.partialPrivateSharedSchema schemaForClassName:_objectClassName];
    }

    return LEGACYValidatedProperty(objectSchema, propertyName).type;
}

- (id)aggregateProperty:(NSString *)key operation:(NSString *)op method:(SEL)sel {
    // Although delegating to valueForKeyPath: here would allow to support
    // nested key paths as well, limiting functionality gives consistency
    // between unmanaged and managed arrays.
    if ([key rangeOfString:@"."].location != NSNotFound) {
        @throw LEGACYException(@"Nested key paths are not supported yet for KVC collection operators.");
    }

    if ([op isEqualToString:@"@distinctUnionOfObjects"]) {
        @throw LEGACYException(@"this class does not implement the distinctUnionOfObjects");
    }

    bool allowDate = false;
    bool sum = false;
    if ([op isEqualToString:@"@min"] || [op isEqualToString:@"@max"]) {
        allowDate = true;
    }
    else if ([op isEqualToString:@"@sum"]) {
        sum = true;
    }
    else if (![op isEqualToString:@"@avg"]) {
        // Just delegate to NSSet for all other operators
        return [_backingCollection valueForKeyPath:[op stringByAppendingPathExtension:key]];
    }

    LEGACYPropertyType type = [self typeForProperty:key];
    if (!canAggregate(type, allowDate)) {
        NSString *method = sel ? NSStringFromSelector(sel) : op;
        if (_type == LEGACYPropertyTypeObject) {
            @throw LEGACYException(@"%@: is not supported for %@ property '%@.%@'",
                                method, LEGACYTypeToString(type), _objectClassName, key);
        }
        else {
            @throw LEGACYException(@"%@ is not supported for %@%s set",
                                method, LEGACYTypeToString(_type), _optional ? "?" : "");
        }
    }

    // `valueForKeyPath` on NSSet will only return distinct values, which is an
    // issue as the realm::object_store::Set aggregate methods will calculate
    // the result based on each element of a property regardless of uniqueness.
    // To get around this we will need to use the `array` property of the NSMutableOrderedSet
    NSArray *values = [key isEqualToString:@"self"] ? _backingCollection.array : [_backingCollection.array valueForKey:key];
    if (_optional) {
        // Filter out NSNull values to match our behavior on managed arrays
        NSIndexSet *nonnull = [values indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger, BOOL *) {
            return obj != NSNull.null;
        }];
        if (nonnull.count < values.count) {
            values = [values objectsAtIndexes:nonnull];
        }
    }

    id result = [values valueForKeyPath:[op stringByAppendingString:@".self"]];
    return sum && !result ? @0 : result;
}

static NSSet *toUnorderedSet(id value) {
    if (auto orderedSet = LEGACYDynamicCast<NSOrderedSet>(value)) {
        return orderedSet.set;
    }
    return value;
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath characterAtIndex:0] != '@') {
        return toUnorderedSet(_backingCollection ? [_backingCollection valueForKeyPath:keyPath] : [super valueForKeyPath:keyPath]);
    }

    if (!_backingCollection) {
        _backingCollection = [NSMutableOrderedSet new];
    }

    NSUInteger dot = [keyPath rangeOfString:@"."].location;
    if (dot == NSNotFound) {
        return [_backingCollection valueForKeyPath:keyPath];
    }

    NSString *op = [keyPath substringToIndex:dot];
    NSString *key = [keyPath substringFromIndex:dot + 1];
    return [self aggregateProperty:key operation:op method:nil];
}

- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:LEGACYInvalidatedKey]) {
        return @NO; // Unmanaged sets are never invalidated
    }
    if (!_backingCollection) {
        _backingCollection = [NSMutableOrderedSet new];
    }
    return toUnorderedSet([_backingCollection valueForKey:key]);
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"self"]) {
        LEGACYSetValidateMatchingObjectType(self, value);
        [_backingCollection removeAllObjects];
        [_backingCollection addObject:value];
        return;
    }
    else if (_type == LEGACYPropertyTypeObject) {
        [_backingCollection setValue:value forKey:key];
    }
    else {
        [self setValue:value forUndefinedKey:key];
    }
}

- (id)minOfProperty:(NSString *)property {
    return [self aggregateProperty:property operation:@"@min" method:_cmd];
}

- (id)maxOfProperty:(NSString *)property {
    return [self aggregateProperty:property operation:@"@max" method:_cmd];
}

- (id)sumOfProperty:(NSString *)property {
    return [self aggregateProperty:property operation:@"@sum" method:_cmd];
}

- (id)averageOfProperty:(NSString *)property {
    return [self aggregateProperty:property operation:@"@avg" method:_cmd];
}

- (BOOL)isEqual:(id)object {
    if (auto set = LEGACYDynamicCast<LEGACYSet>(object)) {
        return !set.realm
        && ((_backingCollection.count == 0 && set->_backingCollection.count == 0)
            || [_backingCollection isEqual:set->_backingCollection]);
    }
    return NO;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options context:(void *)context {
    LEGACYValidateSetObservationKey(keyPath, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

void LEGACYSetValidateMatchingObjectType(__unsafe_unretained LEGACYSet *const set,
                                      __unsafe_unretained id const value) {
    if (!value && !set->_optional) {
        @throw LEGACYException(@"Invalid nil value for set of '%@'.",
                            set->_objectClassName ?: LEGACYTypeToString(set->_type));
    }
    if (set->_type != LEGACYPropertyTypeObject) {
        if (!LEGACYValidateValue(value, set->_type, set->_optional, false, nil)) {
            @throw LEGACYException(@"Invalid value '%@' of type '%@' for expected type '%@%s'.",
                                value, [value class], LEGACYTypeToString(set->_type),
                                set->_optional ? "?" : "");
        }
        return;
    }

    auto object = LEGACYDynamicCast<LEGACYObjectBase>(value);
    if (!object) {
        return;
    }
    if (!object->_objectSchema) {
        @throw LEGACYException(@"Object cannot be inserted unless the schema is initialized. "
                            "This can happen if you try to insert objects into a LEGACYSet / Set from a default value or from an overriden unmanaged initializer (`init()`).");
    }
    if (![set->_objectClassName isEqualToString:object->_objectSchema.className]
        && (set->_type != LEGACYPropertyTypeAny)) {
        @throw LEGACYException(@"Object of type '%@' does not match LEGACYSet type '%@'.",
                            object->_objectSchema.className, set->_objectClassName);
    }
}

#pragma mark - Key Path Strings

- (NSString *)propertyKey {
    return _key;
}

#pragma mark - Methods unsupported on unmanaged LEGACYSet instances

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"

- (LEGACYResults *)objectsWithPredicate:(NSPredicate *)predicate {
    @throw LEGACYException(@"This method may only be called on LEGACYSet instances retrieved from an LEGACYRealm");
}

- (LEGACYResults *)sortedResultsUsingDescriptors:(NSArray<LEGACYSortDescriptor *> *)properties {
    @throw LEGACYException(@"This method may only be called on LEGACYSet instances retrieved from an LEGACYRealm");
}

- (LEGACYResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    @throw LEGACYException(@"This method may only be called on LEGACYSet instances retrieved from an LEGACYRealm");
}

- (LEGACYSectionedResults *)sectionedResultsSortedUsingKeyPath:(NSString *)keyPath
                                                  ascending:(BOOL)ascending
                                                   keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock {
    @throw LEGACYException(@"This method may only be called on LEGACYSet instances retrieved from an LEGACYRealm");
}

- (LEGACYSectionedResults *)sectionedResultsUsingSortDescriptors:(NSArray<LEGACYSortDescriptor *> *)sortDescriptors
                                                     keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock {
    @throw LEGACYException(@"This method may only be called on LEGACYSet instances retrieved from an LEGACYRealm");
}

- (instancetype)freeze {
    @throw LEGACYException(@"This method may only be called on LEGACYSet instances retrieved from an LEGACYRealm");
}

- (instancetype)thaw {
    @throw LEGACYException(@"This method may only be called on LEGACYSet instances retrieved from an LEGACYRealm");
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYSet`");
}

- (id)objectiveCMetadata {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYSet`");
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(id)metadata
                                        realm:(LEGACYRealm *)realm {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYSet`");
}

#pragma clang diagnostic pop // unused parameter warning

#pragma mark - Superclass Overrides

- (NSString *)description {
    return [self descriptionWithMaxDepth:LEGACYDescriptionMaxDepth];
}

- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth {
    return LEGACYDescriptionWithMaxDepth(@"LEGACYSet", self, depth);
}
@end
