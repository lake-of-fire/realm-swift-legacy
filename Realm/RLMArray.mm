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

#import "LEGACYArray_Private.hpp"

#import "LEGACYObjectSchema.h"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.h"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYSchema_Private.h"
#import "LEGACYSwiftSupport.h"
#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUtil.hpp"

@interface LEGACYArray () <LEGACYThreadConfined_Private>
@end

@implementation LEGACYArray {
    // Backing array when this instance is unmanaged
    @public
    NSMutableArray *_backingCollection;
}
#pragma mark - Initializers

- (instancetype)initWithObjectClassName:(__unsafe_unretained NSString *const)objectClassName
                                keyType:(__unused LEGACYPropertyType)keyType {
    return [self initWithObjectClassName:objectClassName];
}
- (instancetype)initWithObjectType:(LEGACYPropertyType)type optional:(BOOL)optional
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
    REALM_ASSERT(type != LEGACYPropertyTypeObject);
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

#pragma mark - Convenience wrappers used for all LEGACYArray types

- (void)addObjects:(id<NSFastEnumeration>)objects {
    for (id obj in objects) {
        [self addObject:obj];
    }
}

- (void)addObject:(id)object {
    [self insertObject:object atIndex:self.count];
}

- (void)removeLastObject {
    NSUInteger count = self.count;
    if (count) {
        [self removeObjectAtIndex:count-1];
    }
}

- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

- (void)setObject:(id)newValue atIndexedSubscript:(NSUInteger)index {
    [self replaceObjectAtIndex:index withObject:newValue];
}

- (LEGACYResults *)sortedResultsUsingKeyPath:(NSString *)keyPath ascending:(BOOL)ascending {
    return [self sortedResultsUsingDescriptors:@[[LEGACYSortDescriptor sortDescriptorWithKeyPath:keyPath ascending:ascending]]];
}

- (NSUInteger)indexOfObjectWhere:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    NSUInteger index = [self indexOfObjectWhere:predicateFormat args:args];
    va_end(args);
    return index;
}

- (NSUInteger)indexOfObjectWhere:(NSString *)predicateFormat args:(va_list)args {
    return [self indexOfObjectWithPredicate:[NSPredicate predicateWithFormat:predicateFormat
                                                                   arguments:args]];
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
    return LEGACYAddNotificationBlock(self, block, keyPaths, nil);
}

- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYArray *, LEGACYCollectionChange *, NSError *))block
                                      keyPaths:(NSArray<NSString *> *)keyPaths
                                         queue:(dispatch_queue_t)queue {
    return LEGACYAddNotificationBlock(self, block, keyPaths, queue);
}
#pragma clang diagnostic pop

#pragma mark - Unmanaged LEGACYArray implementation

- (LEGACYRealm *)realm {
    return nil;
}

- (id)firstObject {
    if (self.count) {
        return [self objectAtIndex:0];
    }
    return nil;
}

- (id)lastObject {
    NSUInteger count = self.count;
    if (count) {
        return [self objectAtIndex:count-1];
    }
    return nil;
}

- (id)objectAtIndex:(NSUInteger)index {
    validateArrayBounds(self, index);
    return [_backingCollection objectAtIndex:index];
}

- (NSUInteger)count {
    return _backingCollection.count;
}

- (BOOL)isInvalidated {
    return NO;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(__unused NSUInteger)len {
    return LEGACYUnmanagedFastEnumerate(_backingCollection, state);
}

template<typename IndexSetFactory>
static void changeArray(__unsafe_unretained LEGACYArray *const ar,
                        NSKeyValueChange kind, dispatch_block_t f, IndexSetFactory&& is) {
    if (!ar->_backingCollection) {
        ar->_backingCollection = [NSMutableArray new];
    }

    if (LEGACYObjectBase *parent = ar->_parentObject) {
        NSIndexSet *indexes = is();
        [parent willChange:kind valuesAtIndexes:indexes forKey:ar->_key];
        f();
        [parent didChange:kind valuesAtIndexes:indexes forKey:ar->_key];
    }
    else {
        f();
    }
}

static void changeArray(__unsafe_unretained LEGACYArray *const ar, NSKeyValueChange kind,
                        NSUInteger index, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return [NSIndexSet indexSetWithIndex:index]; });
}

static void changeArray(__unsafe_unretained LEGACYArray *const ar, NSKeyValueChange kind,
                        NSRange range, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return [NSIndexSet indexSetWithIndexesInRange:range]; });
}

static void changeArray(__unsafe_unretained LEGACYArray *const ar, NSKeyValueChange kind,
                        NSIndexSet *is, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return is; });
}

void LEGACYArrayValidateMatchingObjectType(__unsafe_unretained LEGACYArray *const array,
                                        __unsafe_unretained id const value) {
    if (!value && !array->_optional) {
        @throw LEGACYException(@"Invalid nil value for array of '%@'.",
                            array->_objectClassName ?: LEGACYTypeToString(array->_type));
    }
    if (array->_type != LEGACYPropertyTypeObject) {
        if (!LEGACYValidateValue(value, array->_type, array->_optional, false, nil)) {
            @throw LEGACYException(@"Invalid value '%@' of type '%@' for expected type '%@%s'.",
                                value, [value class], LEGACYTypeToString(array->_type),
                                array->_optional ? "?" : "");
        }
        return;
    }

    auto object = LEGACYDynamicCast<LEGACYObjectBase>(value);
    if (!object) {
        return;
    }
    if (!object->_objectSchema) {
        @throw LEGACYException(@"Object cannot be inserted unless the schema is initialized. "
                            "This can happen if you try to insert objects into a LEGACYArray / List from a default value or from an overriden unmanaged initializer (`init()`).");
    }
    if (![array->_objectClassName isEqualToString:object->_objectSchema.className]) {
        @throw LEGACYException(@"Object of type '%@' does not match LEGACYArray type '%@'.",
                            object->_objectSchema.className, array->_objectClassName);
    }
}

static void validateArrayBounds(__unsafe_unretained LEGACYArray *const ar,
                                   NSUInteger index, bool allowOnePastEnd=false) {
    NSUInteger max = ar->_backingCollection.count + allowOnePastEnd;
    if (index >= max) {
        @throw LEGACYException(@"Index %llu is out of bounds (must be less than %llu).",
                            (unsigned long long)index, (unsigned long long)max);
    }
}

- (void)addObjectsFromArray:(NSArray *)array {
    for (id obj in array) {
        LEGACYArrayValidateMatchingObjectType(self, obj);
    }
    changeArray(self, NSKeyValueChangeInsertion, NSMakeRange(_backingCollection.count, array.count), ^{
        [_backingCollection addObjectsFromArray:array];
    });
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index {
    LEGACYArrayValidateMatchingObjectType(self, anObject);
    validateArrayBounds(self, index, true);
    changeArray(self, NSKeyValueChangeInsertion, index, ^{
        [_backingCollection insertObject:anObject atIndex:index];
    });
}

- (void)insertObjects:(id<NSFastEnumeration>)objects atIndexes:(NSIndexSet *)indexes {
    changeArray(self, NSKeyValueChangeInsertion, indexes, ^{
        NSUInteger currentIndex = [indexes firstIndex];
        for (LEGACYObject *obj in objects) {
            LEGACYArrayValidateMatchingObjectType(self, obj);
            [_backingCollection insertObject:obj atIndex:currentIndex];
            currentIndex = [indexes indexGreaterThanIndex:currentIndex];
        }
    });
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    validateArrayBounds(self, index);
    changeArray(self, NSKeyValueChangeRemoval, index, ^{
        [_backingCollection removeObjectAtIndex:index];
    });
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes {
    changeArray(self, NSKeyValueChangeRemoval, indexes, ^{
        [_backingCollection removeObjectsAtIndexes:indexes];
    });
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject {
    LEGACYArrayValidateMatchingObjectType(self, anObject);
    validateArrayBounds(self, index);
    changeArray(self, NSKeyValueChangeReplacement, index, ^{
        [_backingCollection replaceObjectAtIndex:index withObject:anObject];
    });
}

- (void)moveObjectAtIndex:(NSUInteger)sourceIndex toIndex:(NSUInteger)destinationIndex {
    validateArrayBounds(self, sourceIndex);
    validateArrayBounds(self, destinationIndex);
    id original = _backingCollection[sourceIndex];

    auto start = std::min(sourceIndex, destinationIndex);
    auto len = std::max(sourceIndex, destinationIndex) - start + 1;
    changeArray(self, NSKeyValueChangeReplacement, {start, len}, ^{
        [_backingCollection removeObjectAtIndex:sourceIndex];
        [_backingCollection insertObject:original atIndex:destinationIndex];
    });
}

- (void)exchangeObjectAtIndex:(NSUInteger)index1 withObjectAtIndex:(NSUInteger)index2 {
    validateArrayBounds(self, index1);
    validateArrayBounds(self, index2);

    changeArray(self, NSKeyValueChangeReplacement, ^{
        [_backingCollection exchangeObjectAtIndex:index1 withObjectAtIndex:index2];
    }, [=] {
        NSMutableIndexSet *set = [[NSMutableIndexSet alloc] initWithIndex:index1];
        [set addIndex:index2];
        return set;
    });
}

- (NSUInteger)indexOfObject:(id)object {
    LEGACYArrayValidateMatchingObjectType(self, object);
    if (!_backingCollection) {
        return NSNotFound;
    }
    if (_type != LEGACYPropertyTypeObject) {
        return [_backingCollection indexOfObject:object];
    }

    NSUInteger index = 0;
    for (LEGACYObjectBase *cmp in _backingCollection) {
        if (LEGACYObjectBaseAreEqual(object, cmp)) {
            return index;
        }
        index++;
    }
    return NSNotFound;
}

- (void)removeAllObjects {
    changeArray(self, NSKeyValueChangeRemoval, NSMakeRange(0, _backingCollection.count), ^{
        [_backingCollection removeAllObjects];
    });
}

- (void)replaceAllObjectsWithObjects:(NSArray *)objects {
    if (_backingCollection.count) {
        changeArray(self, NSKeyValueChangeRemoval, NSMakeRange(0, _backingCollection.count), ^{
            [_backingCollection removeAllObjects];
        });
    }
    if (![objects respondsToSelector:@selector(count)] || !objects.count) {
        return;
    }
    changeArray(self, NSKeyValueChangeInsertion, NSMakeRange(0, objects.count), ^{
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

    bool allowDate = false;
    bool sum = false;
    if ([op isEqualToString:@"@min"] || [op isEqualToString:@"@max"]) {
        allowDate = true;
    }
    else if ([op isEqualToString:@"@sum"]) {
        sum = true;
    }
    else if (![op isEqualToString:@"@avg"]) {
        // Just delegate to NSArray for all other operators
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
            @throw LEGACYException(@"%@ is not supported for %@%s array",
                                method, LEGACYTypeToString(_type), _optional ? "?" : "");
        }
    }

    NSArray *values = [key isEqualToString:@"self"] ? _backingCollection : [_backingCollection valueForKey:key];
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

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath characterAtIndex:0] != '@') {
        return _backingCollection ? [_backingCollection valueForKeyPath:keyPath] : [super valueForKeyPath:keyPath];
    }

    if (!_backingCollection) {
        _backingCollection = [NSMutableArray new];
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
        return @NO; // Unmanaged arrays are never invalidated
    }
    if (!_backingCollection) {
        _backingCollection = [NSMutableArray new];
    }
    return [_backingCollection valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"self"]) {
        LEGACYArrayValidateMatchingObjectType(self, value);
        for (NSUInteger i = 0, count = _backingCollection.count; i < count; ++i) {
            _backingCollection[i] = value;
        }
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

- (NSUInteger)indexOfObjectWithPredicate:(NSPredicate *)predicate {
    if (!_backingCollection) {
        return NSNotFound;
    }
    return [_backingCollection indexOfObjectPassingTest:^BOOL(id obj, NSUInteger, BOOL *) {
        return [predicate evaluateWithObject:obj];
    }];
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes {
    if ([indexes indexGreaterThanOrEqualToIndex:self.count] != NSNotFound) {
        return nil;
    }
    return [_backingCollection objectsAtIndexes:indexes] ?: @[];
}

- (BOOL)isEqual:(id)object {
    if (auto array = LEGACYDynamicCast<LEGACYArray>(object)) {
        if (array.realm) {
            return NO;
        }
        NSArray *otherCollection = array->_backingCollection;
        return (_backingCollection.count == 0 && otherCollection.count == 0)
            || [_backingCollection isEqual:otherCollection];
    }
    return NO;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options context:(void *)context {
    LEGACYValidateArrayObservationKey(keyPath, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

#pragma mark - Methods unsupported on unmanaged LEGACYArray instances

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"

- (LEGACYResults *)objectsWithPredicate:(NSPredicate *)predicate {
    @throw LEGACYException(@"This method may only be called on LEGACYArray instances retrieved from an LEGACYRealm");
}

- (LEGACYResults *)sortedResultsUsingDescriptors:(NSArray<LEGACYSortDescriptor *> *)properties {
    @throw LEGACYException(@"This method may only be called on LEGACYArray instances retrieved from an LEGACYRealm");
}

- (LEGACYResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    @throw LEGACYException(@"This method may only be called on LEGACYArray instances retrieved from an LEGACYRealm");
}

- (LEGACYSectionedResults *)sectionedResultsSortedUsingKeyPath:(NSString *)keyPath
                                                  ascending:(BOOL)ascending
                                                   keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock {
    @throw LEGACYException(@"This method may only be called on LEGACYArray instances retrieved from an LEGACYRealm");
}

- (LEGACYSectionedResults *)sectionedResultsUsingSortDescriptors:(NSArray<LEGACYSortDescriptor *> *)sortDescriptors
                                                     keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock {
    @throw LEGACYException(@"This method may only be called on LEGACYArray instances retrieved from an LEGACYRealm");
}

- (instancetype)freeze {
    @throw LEGACYException(@"This method may only be called on LEGACYArray instances retrieved from an LEGACYRealm");
}

- (instancetype)thaw {
    @throw LEGACYException(@"This method may only be called on LEGACYArray instances retrieved from an LEGACYRealm");
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYArray`");
}

- (id)objectiveCMetadata {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYArray`");
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(id)metadata
                                        realm:(LEGACYRealm *)realm {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYArray`");
}

#pragma clang diagnostic pop // unused parameter warning

#pragma mark - Superclass Overrides

- (NSString *)description {
    return [self descriptionWithMaxDepth:LEGACYDescriptionMaxDepth];
}

- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth {
    return LEGACYDescriptionWithMaxDepth(@"LEGACYArray", self, depth);
}

#pragma mark - Key Path Strings

- (NSString *)propertyKey {
    return _key;
}

@end

@implementation LEGACYSortDescriptor

+ (instancetype)sortDescriptorWithKeyPath:(NSString *)keyPath ascending:(BOOL)ascending {
    LEGACYSortDescriptor *desc = [[LEGACYSortDescriptor alloc] init];
    desc->_keyPath = keyPath;
    desc->_ascending = ascending;
    return desc;
}

- (instancetype)reversedSortDescriptor {
    return [self.class sortDescriptorWithKeyPath:_keyPath ascending:!_ascending];
}

@end
