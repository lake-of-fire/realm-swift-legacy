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

#import "LEGACYAccessor.hpp"
#import "LEGACYCollection_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYObservation.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYRealmConfiguration_Private.hpp"
#import "LEGACYSchema.h"
#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/table_view.hpp>

@interface LEGACYManagedDictionary () <LEGACYThreadConfined_Private> {
    @public
    realm::object_store::Dictionary _backingCollection;
}
@end

@implementation LEGACYDictionaryChange {
    realm::DictionaryChangeSet _changes;
}

- (instancetype)initWithChanges:(realm::DictionaryChangeSet const&)changes {
    self = [super init];
    if (self) {
        _changes = changes;
    }
    return self;
}

static NSArray *toArray(std::vector<realm::Mixed> const& v) {
    NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:v.size()];
    for (auto& mixed : v) {
        [ret addObject:LEGACYMixedToObjc(mixed)];
    }
    return ret;
}

- (NSArray *)insertions {
    return toArray(_changes.insertions);
}

- (NSArray *)deletions {
    return toArray(_changes.deletions);
}

- (NSArray *)modifications {
    return toArray(_changes.modifications);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<LEGACYDictionaryChange: %p> insertions: %@, deletions: %@, modifications: %@",
            (__bridge void *)self, self.insertions, self.deletions, self.modifications];
}

@end

@interface LEGACYManagedCollectionHandoverMetadata : NSObject
@property (nonatomic) NSString *parentClassName;
@property (nonatomic) NSString *key;
@end

@implementation LEGACYManagedCollectionHandoverMetadata
@end

@implementation LEGACYManagedDictionary {
@public
    LEGACYRealm *_realm;
    LEGACYClassInfo *_objectInfo;
    LEGACYClassInfo *_ownerInfo;
    std::unique_ptr<LEGACYObservationInfo> _observationInfo;
}

- (LEGACYManagedDictionary *)initWithBackingCollection:(realm::object_store::Dictionary)dictionary
                                         parentInfo:(LEGACYClassInfo *)parentInfo
                                           property:(__unsafe_unretained LEGACYProperty *const)property {
    if (property.type == LEGACYPropertyTypeObject)
        self = [self initWithObjectClassName:property.objectClassName keyType:property.dictionaryKeyType];
    else
        self = [self initWithObjectType:property.type optional:property.optional keyType:property.dictionaryKeyType];
    if (self) {
        _realm = parentInfo->realm;
        REALM_ASSERT(dictionary.get_realm() == _realm->_realm);
        _backingCollection = std::move(dictionary);
        _ownerInfo = parentInfo;
        if (property.type == LEGACYPropertyTypeObject)
            _objectInfo = &parentInfo->linkTargetType(property.index);
        else
            _objectInfo = _ownerInfo;
        _key = property.name;
    }
    return self;
}

- (LEGACYManagedDictionary *)initWithParent:(__unsafe_unretained LEGACYObjectBase *const)parentObject
                                property:(__unsafe_unretained LEGACYProperty *const)property {
    __unsafe_unretained LEGACYRealm *const realm = parentObject->_realm;
    auto col = parentObject->_info->tableColumn(property);
    return [self initWithBackingCollection:realm::object_store::Dictionary(realm->_realm, parentObject->_row, col)
                                parentInfo:parentObject->_info
                                  property:property];
}

- (LEGACYManagedDictionary *)initWithParent:(realm::Obj)parent
                                property:(__unsafe_unretained LEGACYProperty *const)property
                              parentInfo:(LEGACYClassInfo&)info {
    auto col = info.tableColumn(property);
    return [self initWithBackingCollection:realm::object_store::Dictionary(info.realm->_realm, parent, col)
                                parentInfo:&info
                                  property:property];
}

void LEGACYDictionaryValidateObservationKey(__unsafe_unretained NSString *const keyPath,
                                         __unsafe_unretained LEGACYDictionary *const dictionary) {
    if (![keyPath isEqualToString:LEGACYInvalidatedKey]) {
        @throw LEGACYException(@"[<%@ %p> addObserver:forKeyPath:options:context:] is not supported. Key path: %@",
                            [dictionary class], dictionary, keyPath);
    }
}

void LEGACYEnsureDictionaryObservationInfo(std::unique_ptr<LEGACYObservationInfo>& info,
                                        __unsafe_unretained NSString *const keyPath,
                                        __unsafe_unretained LEGACYDictionary *const dictionary,
                                        __unsafe_unretained id const observed) {
    LEGACYDictionaryValidateObservationKey(keyPath, dictionary);
    if (!info && dictionary.class == [LEGACYManagedDictionary class]) {
        auto lv = static_cast<LEGACYManagedDictionary *>(dictionary);
        info = std::make_unique<LEGACYObservationInfo>(*lv->_ownerInfo,
                                                    lv->_backingCollection.get_parent_object_key(),
                                                    observed);
    }
}

//
// validation helpers
//
template<typename Function>
__attribute__((always_inline))
static auto translateErrors(Function&& f) {
    return translateCollectionError(static_cast<Function&&>(f), @"Dictionary");
}

static void changeDictionary(__unsafe_unretained LEGACYManagedDictionary *const dict,
                             dispatch_block_t f) {
    translateErrors([&] { dict->_backingCollection.verify_in_transaction(); });

    LEGACYObservationTracker tracker(dict->_realm);
    tracker.trackDeletions();
    auto obsInfo = LEGACYGetObservationInfo(dict->_observationInfo.get(),
                                         dict->_backingCollection.get_parent_object_key(),
                                         *dict->_ownerInfo);
    if (obsInfo) {
        tracker.willChange(obsInfo, dict->_key);
    }

    translateErrors(f);
}

//
// public method implementations
//
- (LEGACYRealm *)realm {
    return _realm;
}

- (NSUInteger)count {
    return translateErrors([&] {
        return _backingCollection.size();
    });
}

static NSMutableArray *resultsToArray(LEGACYClassInfo& info, realm::Results r) {
    LEGACYAccessorContext c(info);
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:r.size()];
    for (size_t i = 0, size = r.size(); i < size; ++i) {
        [array addObject:r.get(c, i)];
    }
    return array;
}

- (NSArray *)allKeys {
    return translateErrors([&] {
        return resultsToArray(*_objectInfo, _backingCollection.get_keys());
    });
}

- (NSArray *)allValues {
    return translateErrors([&] {
        return resultsToArray(*_objectInfo, _backingCollection.get_values());
    });
}

- (BOOL)isInvalidated {
    return translateErrors([&] { return !_backingCollection.is_valid(); });
}

- (LEGACYClassInfo *)objectInfo {
    return _objectInfo;
}

- (bool)isBackedByDictionary:(realm::object_store::Dictionary const&)dictionary {
    return _backingCollection == dictionary;
}

- (BOOL)isEqual:(id)object {
    return [object respondsToSelector:@selector(isBackedByDictionary:)] &&
           [object isBackedByDictionary:_backingCollection];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return LEGACYFastEnumerate(state, len, self);
}

#pragma mark - Object Retrieval

- (nullable id)objectForKey:(id)key {
    return translateErrors([&]() -> id {
        [self.realm verifyThread];
        LEGACYAccessorContext context(*_objectInfo);
        if (auto value = _backingCollection.try_get_any(context.unbox<realm::StringData>(key))) {
            return context.box(*value);
        }
        return nil;
    });
}

- (void)setObject:(id)obj forKey:(id)key {
    changeDictionary(self, ^{
        LEGACYAccessorContext c(*_objectInfo);
        _backingCollection.insert(c, c.unbox<realm::StringData>(LEGACYDictionaryKey(self, key)),
                                  LEGACYDictionaryValue(self, obj));
    });
}

- (void)removeAllObjects {
    changeDictionary(self, ^{
        _backingCollection.remove_all();
    });
}

- (void)removeObjectsForKeys:(NSArray *)keyArray {
    LEGACYAccessorContext context(*_objectInfo);
    changeDictionary(self, [&] {
        for (id key in keyArray) {
            _backingCollection.try_erase(context.unbox<realm::StringData>(key));
        }
    });
}

- (void)removeObjectForKey:(id)key {
    changeDictionary(self, ^{
        LEGACYAccessorContext context(*_objectInfo);
        _backingCollection.try_erase(context.unbox<realm::StringData>(key));
    });
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    LEGACYAccessorContext c(*_objectInfo);
    BOOL stop = false;
    @autoreleasepool {
        for (auto&& [key, value] : _backingCollection) {
            block(c.box(key), c.box(value), &stop);
            if (stop) {
                break;
            }
        }
    }
}

- (void)mergeDictionary:(id)dictionary clear:(bool)clear {
    if (!clear && !dictionary) {
        return;
    }
    if (dictionary && ![dictionary respondsToSelector:@selector(enumerateKeysAndObjectsUsingBlock:)]) {
        @throw LEGACYException(@"Cannot %@ object of class '%@'",
                            clear ? @"set dictionary to" : @"add entries from",
                            [dictionary className]);
    }

    changeDictionary(self, ^{
        LEGACYAccessorContext c(*_objectInfo);
        if (clear) {
            _backingCollection.remove_all();
        }
        [dictionary enumerateKeysAndObjectsUsingBlock:[&](id key, id value, BOOL *) {
            _backingCollection.insert(c, c.unbox<realm::StringData>(LEGACYDictionaryKey(self, key)),
                                      LEGACYDictionaryValue(self, value));
        }];
    });
}

- (void)setDictionary:(id)dictionary {
    [self mergeDictionary:LEGACYCoerceToNil(dictionary) clear:true];
}

- (void)addEntriesFromDictionary:(id)otherDictionary {
    [self mergeDictionary:otherDictionary clear:false];
}

#pragma mark - KVC

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) {
        // Delegate KVC collection operators to LEGACYResults
        return translateErrors([&] {
            auto results = [LEGACYResults resultsWithObjectInfo:*_objectInfo
                                                     results:_backingCollection.as_results()];
            return [results valueForKeyPath:keyPath];
        });
    }
    return [super valueForKeyPath:keyPath];
}

- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:LEGACYInvalidatedKey]) {
        return @(!_backingCollection.is_valid());
    }
    return [self objectForKey:key];
}

- (void)setValue:(id)value forKey:(nonnull NSString *)key {
    [self setObject:value forKeyedSubscript:key];
}

- (id)minOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingCollection, _objectInfo, _type, LEGACYCollectionTypeDictionary);
    auto value = translateErrors([&] {
        return _backingCollection.as_results().min(column);
    });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (id)maxOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingCollection, _objectInfo, _type, LEGACYCollectionTypeDictionary);
    auto value = translateErrors([&] {
        return _backingCollection.as_results().max(column);
    });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (id)sumOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingCollection, _objectInfo, _type, LEGACYCollectionTypeDictionary);
    auto value = translateErrors([&] {
        return _backingCollection.as_results().sum(column);
    });
    return value ? LEGACYMixedToObjc(*value) : @0;
}

- (id)averageOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingCollection, _objectInfo, _type, LEGACYCollectionTypeDictionary);
    auto value = translateErrors([&] {
        return _backingCollection.as_results().average(column);
    });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (void)deleteObjectsFromRealm {
    if (_type != LEGACYPropertyTypeObject) {
        @throw LEGACYException(@"Cannot delete objects from LEGACYManagedDictionary<LEGACYString, %@%@>: only LEGACYObjects can be deleted.", LEGACYTypeToString(_type), _optional? @"?": @"");
    }
    // delete all target rows from the realm
    LEGACYObservationTracker tracker(_realm, true);
    translateErrors([&] {
        for (auto&& [key, value] : _backingCollection) {
            _realm.group.get_object(value.get_link()).remove();
        }
        _backingCollection.remove_all();
    });
}

- (LEGACYResults *)sortedResultsUsingDescriptors:(NSArray<LEGACYSortDescriptor *> *)properties {
    return translateErrors([&] {
        return [LEGACYResults resultsWithObjectInfo:*_objectInfo
                                         results:_backingCollection.as_results().sort(LEGACYSortDescriptorsToKeypathArray(properties))];
    });
}

- (LEGACYResults *)sortedResultsUsingKeyPath:(nonnull NSString *)keyPath ascending:(BOOL)ascending {
    return [self sortedResultsUsingDescriptors:@[[LEGACYSortDescriptor sortDescriptorWithKeyPath:keyPath ascending:ascending]]];
}

- (LEGACYResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    return translateErrors([&] {
        auto results = [LEGACYResults resultsWithObjectInfo:*_objectInfo results:_backingCollection.as_results()];
        return [results distinctResultsUsingKeyPaths:keyPaths];
    });
}

- (LEGACYResults *)objectsWithPredicate:(NSPredicate *)predicate {
    if (_type != LEGACYPropertyTypeObject) {
        @throw LEGACYException(@"Querying is currently only implemented for dictionaries of Realm Objects");
    }
    auto query = LEGACYPredicateToQuery(predicate, _objectInfo->rlmObjectSchema, _realm.schema, _realm.group);
    auto results = translateErrors([&] {
        return _backingCollection.as_results().filter(std::move(query));
    });
    return [LEGACYResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    LEGACYEnsureDictionaryObservationInfo(_observationInfo, keyPath, self, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (realm::TableView)tableView {
    return translateErrors([&] {
        return _backingCollection.as_results().get_query();
    }).find_all();
}

- (LEGACYFastEnumerator *)fastEnumerator {
    return translateErrors([&] {
        return [[LEGACYFastEnumerator alloc] initWithBackingDictionary:_backingCollection
                                                         dictionary:self
                                                          classInfo:*_objectInfo];
    });
}

- (BOOL)isFrozen {
    return _realm.isFrozen;
}

- (instancetype)resolveInRealm:(LEGACYRealm *)realm {
    auto& parentInfo = _ownerInfo->resolve(realm);
    return translateErrors([&] {
        return [[self.class alloc] initWithBackingCollection:_backingCollection.freeze(realm->_realm)
                                                  parentInfo:&parentInfo
                                                    property:parentInfo.rlmObjectSchema[_key]];
    });
}

- (instancetype)freeze {
    if (self.frozen) {
        return self;
    }
    return [self resolveInRealm:_realm.freeze];
}

- (instancetype)thaw {
    if (!self.frozen) {
        return self;
    }
    return [self resolveInRealm:_realm.thaw];
}

namespace {
struct DictionaryCallbackWrapper {
    void (^block)(id, LEGACYDictionaryChange *, NSError *);
    LEGACYManagedDictionary *collection;
    realm::TransactionRef previousTransaction;

    DictionaryCallbackWrapper(void (^block)(id, LEGACYDictionaryChange *, NSError *), LEGACYManagedDictionary *dictionary)
    : block(block)
    , collection(dictionary)
    , previousTransaction(static_cast<realm::Transaction&>(collection.realm.group).duplicate())
    {
    }

    void operator()(realm::DictionaryChangeSet const& changes) {
        if (changes.deletions.empty() && changes.insertions.empty() && changes.modifications.empty()) {
            block(collection, nil, nil);
        }
        else {
            block(collection, [[LEGACYDictionaryChange alloc] initWithChanges:changes], nil);
        }
        if (collection.isInvalidated) {
            previousTransaction->end_read();
        }
        else {
            previousTransaction->advance_read(static_cast<realm::Transaction&>(collection.realm.group).get_version_of_current_transaction());
        }
    }
};
} // anonymous namespace

- (realm::NotificationToken)addNotificationCallback:(id)block
keyPaths:(std::optional<std::vector<std::vector<std::pair<realm::TableKey, realm::ColKey>>>>&&)keyPaths {
    return _backingCollection.add_key_based_notification_callback(DictionaryCallbackWrapper{block, self},
                                                                  std::move(keyPaths));
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return _backingCollection;
}

- (LEGACYManagedCollectionHandoverMetadata *)objectiveCMetadata {
    LEGACYManagedCollectionHandoverMetadata *metadata = [[LEGACYManagedCollectionHandoverMetadata alloc] init];
    metadata.parentClassName = _ownerInfo->rlmObjectSchema.className;
    metadata.key = _key;
    return metadata;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(LEGACYManagedCollectionHandoverMetadata *)metadata
                                        realm:(LEGACYRealm *)realm {
    auto dictionary = reference.resolve<realm::object_store::Dictionary>(realm->_realm);
    if (!dictionary.is_valid()) {
        return nil;
    }
    LEGACYClassInfo *parentInfo = &realm->_info[metadata.parentClassName];
    return [[LEGACYManagedDictionary alloc] initWithBackingCollection:std::move(dictionary)
                                                        parentInfo:parentInfo
                                                          property:parentInfo->rlmObjectSchema[metadata.key]];
}

@end
