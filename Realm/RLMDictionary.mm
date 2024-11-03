////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
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

#import "LEGACYDictionary_Private.hpp"
#import "LEGACYObject_Private.h"
#import "LEGACYObjectSchema.h"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYSchema_Private.h"
#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUtil.hpp"

@interface LEGACYDictionary () <LEGACYThreadConfined_Private>
@end

@implementation NSString (LEGACYDictionaryKey)
@end

@implementation LEGACYDictionary {
@public
    // Backing dictionary when this instance is unmanaged
    NSMutableDictionary *_backingCollection;
}

#pragma mark Initializers

- (instancetype)initWithObjectClassName:(__unsafe_unretained NSString *const)objectClassName
                                keyType:(LEGACYPropertyType)keyType {
    REALM_ASSERT([objectClassName length] > 0);
    REALM_ASSERT(LEGACYValidateKeyType(keyType));
    self = [super init];
    if (self) {
        _objectClassName = objectClassName;
        _type = LEGACYPropertyTypeObject;
        _keyType = keyType;
        _optional = YES;
    }
    return self;
}

- (instancetype)initWithObjectType:(LEGACYPropertyType)type optional:(BOOL)optional keyType:(LEGACYPropertyType)keyType {
    REALM_ASSERT(LEGACYValidateKeyType(keyType));
    REALM_ASSERT(type != LEGACYPropertyTypeObject);
    self = [super init];
    if (self) {
        _type = type;
        _keyType = keyType;
        _optional = optional;
    }
    return self;
}

- (void)setParent:(LEGACYObjectBase *)parentObject property:(LEGACYProperty *)property {
    _parentObject = parentObject;
    _key = property.name;
    _isLegacyProperty = property.isLegacy;
}

static bool LEGACYValidateKeyType(LEGACYPropertyType keyType) {
    switch (keyType) {
        case LEGACYPropertyTypeString:
            return true;
        default:
            return false;
    }
}

id LEGACYDictionaryKey(__unsafe_unretained LEGACYDictionary *const dictionary,
                    __unsafe_unretained id const key) {
    if (!key) {
        @throw LEGACYException(@"Invalid nil key for dictionary expecting key of type '%@'.",
                            dictionary->_objectClassName ?: LEGACYTypeToString(dictionary.keyType));
    }
    id validated = LEGACYValidateValue(key, dictionary.keyType, false, false, nil);
    if (!validated) {
        @throw LEGACYException(@"Invalid key '%@' of type '%@' for expected type '%@'.",
                            key, [key class], LEGACYTypeToString(dictionary.keyType));
    }
    return validated;
}

id LEGACYDictionaryValue(__unsafe_unretained LEGACYDictionary *const dictionary,
                      __unsafe_unretained id const value) {
    if (!value) {
        return value;
    }
    if (dictionary->_type != LEGACYPropertyTypeObject) {
        id validated = LEGACYValidateValue(value, dictionary->_type, dictionary->_optional, false, nil);
        if (!validated) {
            @throw LEGACYException(@"Invalid value '%@' of type '%@' for expected type '%@%s'.",
                                value, [value class], LEGACYTypeToString(dictionary->_type),
                                dictionary->_optional ? "?" : "");
        }
        return validated;
    }

    if (auto valueObject = LEGACYDynamicCast<LEGACYObjectBase>(value)) {
        if (!valueObject->_objectSchema) {
            @throw LEGACYException(@"Object cannot be inserted unless the schema is initialized. "
                                "This can happen if you try to insert objects into a LEGACYDictionary / Map from a default value or from an overridden unmanaged initializer (`init()`) or if the key is uninitialized.");
        }
        if (![dictionary->_objectClassName isEqualToString:valueObject->_objectSchema.className]) {
            @throw LEGACYException(@"Value of type '%@' does not match LEGACYDictionary value type '%@'.",
                                valueObject->_objectSchema.className, dictionary->_objectClassName);
        }
    }
    else if (![value isKindOfClass:NSNull.class]) {
        @throw LEGACYException(@"Value of type '%@' does not match LEGACYDictionary value type '%@'.",
                            [value className], dictionary->_objectClassName);
    }

    return value;
}

static void changeDictionary(__unsafe_unretained LEGACYDictionary *const dictionary,
                             dispatch_block_t f) {
    if (!dictionary->_backingCollection) {
        dictionary->_backingCollection = [NSMutableDictionary new];
    }
    if (LEGACYObjectBase *parent = dictionary->_parentObject) {
        [parent willChangeValueForKey:dictionary->_key];
        f();
        [parent didChangeValueForKey:dictionary->_key];
    }
    else {
        f();
    }
}

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYDictionary *, LEGACYDictionaryChange *, NSError *))block {
    return LEGACYAddNotificationBlock(self, block, nil, nil);
}
- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYDictionary *, LEGACYDictionaryChange *, NSError *))block
                                         queue:(dispatch_queue_t)queue {
    return LEGACYAddNotificationBlock(self, block, nil, queue);
}

- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYDictionary *, LEGACYDictionaryChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
                                         queue:(dispatch_queue_t)queue {
    return LEGACYAddNotificationBlock(self, block, keyPaths, queue);
}

- (LEGACYNotificationToken *)addNotificationBlock:(void (^)(LEGACYDictionary *, LEGACYDictionaryChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths {
    return LEGACYAddNotificationBlock(self, block, keyPaths, nil);
}
#pragma clang diagnostic pop

#pragma mark - Unmanaged LEGACYDictionary implementation

- (LEGACYRealm *)realm {
    return nil;
}

- (NSUInteger)count {
    return _backingCollection.count;
}

- (NSArray *)allKeys {
    return _backingCollection.allKeys ?: @[];
}

- (NSArray *)allValues {
    return _backingCollection.allValues ?: @[];
}

- (nullable id)objectForKey:(id)key {
    if (!_backingCollection) {
        _backingCollection = [NSMutableDictionary new];
    }
    return [_backingCollection objectForKey:key];
}

- (nullable id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

- (BOOL)isInvalidated {
    return NO;
}

- (void)setValue:(nullable id)value forKey:(nonnull NSString *)key {
    [self setObject:value forKeyedSubscript:key];
}

- (void)setDictionary:(id)dictionary {
    if (!dictionary || dictionary == NSNull.null) {
        return [self removeAllObjects];
    }
    if (![dictionary respondsToSelector:@selector(enumerateKeysAndObjectsUsingBlock:)]) {
        @throw LEGACYException(@"Cannot set dictionary to object of class '%@'", [dictionary className]);
    }

    changeDictionary(self, ^{
        [_backingCollection removeAllObjects];
        [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *) {
            [_backingCollection setObject:LEGACYDictionaryValue(self, value)
                                   forKey:LEGACYDictionaryKey(self, key)];
        }];
    });
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    if (obj) {
        [self setObject:obj forKey:key];
    }
    else {
        [self removeObjectForKey:key];
    }
}

- (void)setObject:(id)obj forKey:(id)key {
    changeDictionary(self, ^{
        [_backingCollection setObject:LEGACYDictionaryValue(self, obj)
                               forKey:LEGACYDictionaryKey(self, key)];
    });
}

- (void)removeAllObjects {
    changeDictionary(self, ^{
        [_backingCollection removeAllObjects];
    });
}

- (void)removeObjectsForKeys:(NSArray *)keyArray {
    changeDictionary(self, ^{
        [_backingCollection removeObjectsForKeys:keyArray];
    });
}

- (void)removeObjectForKey:(id)key {
    changeDictionary(self, ^{
        [_backingCollection removeObjectForKey:key];
    });
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    [_backingCollection enumerateKeysAndObjectsUsingBlock:block];
}

- (nullable id)valueForKey:(nonnull NSString *)key {
    if ([key isEqualToString:LEGACYInvalidatedKey]) {
        return @NO; // Unmanaged dictionaries are never invalidated
    }
    if (!_backingCollection) {
        _backingCollection = [NSMutableDictionary new];
    }
    return [_backingCollection valueForKey:key];
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath characterAtIndex:0] != '@') {
        return _backingCollection ? [_backingCollection valueForKeyPath:keyPath] : [super valueForKeyPath:keyPath];
    }
    if (!_backingCollection) {
        _backingCollection = [NSMutableDictionary new];
    }
    NSUInteger dot = [keyPath rangeOfString:@"."].location;
    if (dot == NSNotFound) {
        return [_backingCollection valueForKeyPath:keyPath];
    }

    NSString *op = [keyPath substringToIndex:dot];
    NSString *key = [keyPath substringFromIndex:dot + 1];
    return [self aggregateProperty:key operation:op method:nil];
}

- (void)addEntriesFromDictionary:(id)otherDictionary {
    if (!otherDictionary) {
        return;
    }
    if (![otherDictionary respondsToSelector:@selector(enumerateKeysAndObjectsUsingBlock:)]) {
        @throw LEGACYException(@"Cannot add entries from object of class '%@'", [otherDictionary className]);
    }

    changeDictionary(self, ^{
        [otherDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *) {
            _backingCollection[LEGACYDictionaryKey(self, key)] = LEGACYDictionaryValue(self, value);
        }];
    });
}

- (NSUInteger)countByEnumeratingWithState:(nonnull NSFastEnumerationState *)state
                                  objects:(__unsafe_unretained id  _Nullable * _Nonnull)buffer
                                    count:(NSUInteger)len {
    return LEGACYUnmanagedFastEnumerate(_backingCollection.allKeys, state);
}

#pragma mark - Aggregate operations

- (LEGACYPropertyType)typeForProperty:(NSString *)propertyName {
    if ([propertyName isEqualToString:@"self"]) {
        return _type;
    }

    LEGACYObjectSchema *objectSchema;
    if (_backingCollection.count) {
        objectSchema = [_backingCollection.allValues[0] objectSchema];
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
        // Just delegate to NSDictionary for all other operators
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
            @throw LEGACYException(@"%@ is not supported for %@%s dictionary",
                                method, LEGACYTypeToString(_type), _optional ? "?" : "");
        }
    }

    NSArray *values = [key isEqualToString:@"self"] ? _backingCollection.allValues : [_backingCollection.allValues valueForKey:key];

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

- (nonnull LEGACYResults *)objectsWhere:(nonnull NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    LEGACYResults *results = [self objectsWhere:predicateFormat args:args];
    va_end(args);
    return results;
}

- (nonnull LEGACYResults *)objectsWhere:(nonnull NSString *)predicateFormat args:(va_list)args {
    return [self objectsWithPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (BOOL)isEqual:(id)object {
    if (auto dictionary = LEGACYDynamicCast<LEGACYDictionary>(object)) {
        return !dictionary.realm
        && ((_backingCollection.count == 0 && dictionary->_backingCollection.count == 0)
            || [_backingCollection isEqual:dictionary->_backingCollection]);
    }
    return NO;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options context:(void *)context {
    LEGACYDictionaryValidateObservationKey(keyPath, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

#pragma mark - Key Path Strings

- (NSString *)propertyKey {
    return _key;
}

#pragma mark - Methods unsupported on unmanaged LEGACYDictionary instances

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"

- (nonnull LEGACYResults *)objectsWithPredicate:(nonnull NSPredicate *)predicate {
    @throw LEGACYException(@"This method may only be called on LEGACYDictionary instances retrieved from an LEGACYRealm");
}

- (LEGACYResults *)sortedResultsUsingDescriptors:(nonnull NSArray<LEGACYSortDescriptor *> *)properties {
    @throw LEGACYException(@"This method may only be called on LEGACYDictionary instances retrieved from an LEGACYRealm");
}

- (LEGACYResults *)sortedResultsUsingKeyPath:(nonnull NSString *)keyPath ascending:(BOOL)ascending {
    @throw LEGACYException(@"This method may only be called on LEGACYDictionary instances retrieved from an LEGACYRealm");
}

- (LEGACYResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    @throw LEGACYException(@"This method may only be called on LEGACYDictionary instances retrieved from an LEGACYRealm");
}

- (instancetype)freeze {
    @throw LEGACYException(@"This method may only be called on LEGACYDictionary instances retrieved from an LEGACYRealm");
}

- (instancetype)thaw {
    @throw LEGACYException(@"This method may only be called on LEGACYDictionary instances retrieved from an LEGACYRealm");
}

- (NSUInteger)indexOfObject:(id)value {
    @throw LEGACYException(@"This method is not available on LEGACYDictionary.");
}

- (id)objectAtIndex:(NSUInteger)index {
    @throw LEGACYException(@"This method is not available on LEGACYDictionary.");
}

- (nullable NSArray *)objectsAtIndexes:(nonnull NSIndexSet *)indexes {
    @throw LEGACYException(@"This method is not available on LEGACYDictionary.");
}

- (LEGACYSectionedResults *)sectionedResultsSortedUsingKeyPath:(NSString *)keyPath
                                                  ascending:(BOOL)ascending
                                                   keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock {
    @throw LEGACYException(@"This method is not available on LEGACYDictionary.");
}

- (LEGACYSectionedResults *)sectionedResultsUsingSortDescriptors:(NSArray<LEGACYSortDescriptor *> *)sortDescriptors
                                                     keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock {
    @throw LEGACYException(@"This method is not available on LEGACYDictionary.");
}

#pragma clang diagnostic pop // unused parameter warning

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYDictionary`");
}

- (id)objectiveCMetadata {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYDictionary`");
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(id)metadata
                                        realm:(LEGACYRealm *)realm {
    REALM_TERMINATE("Unexpected handover of unmanaged `LEGACYDictionary`");
}

#pragma mark - Superclass Overrides

- (NSString *)description {
    return [self descriptionWithMaxDepth:LEGACYDescriptionMaxDepth];
}

- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth {
    return LEGACYDictionaryDescriptionWithMaxDepth(@"LEGACYDictionary", self, depth);
}

NSString *LEGACYDictionaryDescriptionWithMaxDepth(NSString *name,
                                               LEGACYDictionary *dictionary,
                                               NSUInteger depth) {
    if (depth == 0) {
        return @"<Maximum depth exceeded>";
    }

    const NSUInteger maxObjects = 100;
    auto str = [NSMutableString stringWithFormat:@"%@<%@, %@> <%p> (\n", name,
                LEGACYTypeToString([dictionary keyType]),
                [dictionary objectClassName] ?: LEGACYTypeToString([dictionary type]),
                (void *)dictionary];
    size_t index = 0, skipped = 0;
    for (id key in dictionary) {
        id value = dictionary[key];
        NSString *keyDesc;
        if ([key respondsToSelector:@selector(descriptionWithMaxDepth:)]) {
            keyDesc = [key descriptionWithMaxDepth:depth - 1];
        }
        else {
            keyDesc = [key description];
        }
        NSString *valDesc;
        if ([value respondsToSelector:@selector(descriptionWithMaxDepth:)]) {
            valDesc = [value descriptionWithMaxDepth:depth - 1];
        }
        else {
            valDesc = [value description];
        }

        // Indent child objects
        NSString *sub = [NSString stringWithFormat:@"[%@]: %@", keyDesc, valDesc];
        NSString *objDescription = [sub stringByReplacingOccurrencesOfString:@"\n"
                                                                  withString:@"\n\t"];
        [str appendFormat:@"%@,\n", objDescription];
        if (index >= maxObjects) {
            skipped = dictionary.count - maxObjects;
            break;
        }
    }

    // Remove last comma and newline characters
    if (dictionary.count > 0) {
        [str deleteCharactersInRange:NSMakeRange(str.length-2, 2)];
    }
    if (skipped) {
        [str appendFormat:@"\n\t... %zu objects skipped.", skipped];
    }
    [str appendFormat:@"\n)"];
    return str;
}

@end
