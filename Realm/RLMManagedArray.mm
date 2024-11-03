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

#import "LEGACYAccessor.hpp"
#import "LEGACYCollection_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYObservation.hpp"
#import "LEGACYProperty_Private.hpp"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYRealmConfiguration_Private.hpp"
#import "LEGACYSchema.h"
#import "LEGACYSectionedResults_Private.hpp"
#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/list.hpp>
#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/table_view.hpp>

#import <objc/runtime.h>

@interface LEGACYManagedArrayHandoverMetadata : NSObject
@property (nonatomic) NSString *parentClassName;
@property (nonatomic) NSString *key;
@end

@implementation LEGACYManagedArrayHandoverMetadata
@end

@interface LEGACYManagedArray () <LEGACYThreadConfined_Private>
@end

//
// LEGACYArray implementation
//
@implementation LEGACYManagedArray {
@public
    realm::List _backingList;
    LEGACYRealm *_realm;
    LEGACYClassInfo *_objectInfo;
    LEGACYClassInfo *_ownerInfo;
    std::unique_ptr<LEGACYObservationInfo> _observationInfo;
}

- (LEGACYManagedArray *)initWithBackingCollection:(realm::List)list
                                    parentInfo:(LEGACYClassInfo *)parentInfo
                                      property:(__unsafe_unretained LEGACYProperty *const)property {
    if (property.type == LEGACYPropertyTypeObject)
        self = [self initWithObjectClassName:property.objectClassName];
    else
        self = [self initWithObjectType:property.type
                               optional:property.optional];
    if (self) {
        _realm = parentInfo->realm;
        REALM_ASSERT(list.get_realm() == _realm->_realm);
        _backingList = std::move(list);
        _ownerInfo = parentInfo;
        if (property.type == LEGACYPropertyTypeObject)
            _objectInfo = &parentInfo->linkTargetType(property.index);
        else
            _objectInfo = _ownerInfo;
        _key = property.name;
    }
    return self;
}

- (LEGACYManagedArray *)initWithParent:(__unsafe_unretained LEGACYObjectBase *const)parentObject
                           property:(__unsafe_unretained LEGACYProperty *const)property {
    __unsafe_unretained LEGACYRealm *const realm = parentObject->_realm;
    auto col = parentObject->_info->tableColumn(property);
    return [self initWithBackingCollection:realm::List(realm->_realm, parentObject->_row, col)
                                parentInfo:parentObject->_info
                                  property:property];
}

- (LEGACYManagedArray *)initWithParent:(realm::Obj)parent
                           property:(__unsafe_unretained LEGACYProperty *const)property
                         parentInfo:(LEGACYClassInfo&)info {
    auto col = info.tableColumn(property);
    return [self initWithBackingCollection:realm::List(info.realm->_realm, parent, col)
                                parentInfo:&info
                                  property:property];
}

void LEGACYValidateArrayObservationKey(__unsafe_unretained NSString *const keyPath,
                                    __unsafe_unretained LEGACYArray *const array) {
    if (![keyPath isEqualToString:LEGACYInvalidatedKey]) {
        @throw LEGACYException(@"[<%@ %p> addObserver:forKeyPath:options:context:] is not supported. Key path: %@",
                            [array class], array, keyPath);
    }
}

void LEGACYEnsureArrayObservationInfo(std::unique_ptr<LEGACYObservationInfo>& info,
                                   __unsafe_unretained NSString *const keyPath,
                                   __unsafe_unretained LEGACYArray *const array,
                                   __unsafe_unretained id const observed) {
    LEGACYValidateArrayObservationKey(keyPath, array);
    if (!info && array.class == [LEGACYManagedArray class]) {
        auto lv = static_cast<LEGACYManagedArray *>(array);
        info = std::make_unique<LEGACYObservationInfo>(*lv->_ownerInfo,
                                                    lv->_backingList.get_parent_object_key(),
                                                    observed);
    }
}

template<typename Function>
__attribute__((always_inline))
static auto translateErrors(Function&& f) {
    return translateCollectionError(static_cast<Function&&>(f), @"List");
}

template<typename IndexSetFactory>
static void changeArray(__unsafe_unretained LEGACYManagedArray *const ar,
                        NSKeyValueChange kind, dispatch_block_t f, IndexSetFactory&& is) {
    translateErrors([&] { ar->_backingList.verify_in_transaction(); });

    LEGACYObservationTracker tracker(ar->_realm);
    tracker.trackDeletions();
    auto obsInfo = LEGACYGetObservationInfo(ar->_observationInfo.get(),
                                         ar->_backingList.get_parent_object_key(),
                                         *ar->_ownerInfo);
    if (obsInfo) {
        tracker.willChange(obsInfo, ar->_key, kind, is());
    }

    translateErrors(f);
}

static void changeArray(__unsafe_unretained LEGACYManagedArray *const ar, NSKeyValueChange kind, NSUInteger index, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return [NSIndexSet indexSetWithIndex:index]; });
}

static void changeArray(__unsafe_unretained LEGACYManagedArray *const ar, NSKeyValueChange kind, NSRange range, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return [NSIndexSet indexSetWithIndexesInRange:range]; });
}

static void changeArray(__unsafe_unretained LEGACYManagedArray *const ar, NSKeyValueChange kind, NSIndexSet *is, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return is; });
}

//
// public method implementations
//
- (LEGACYRealm *)realm {
    return _realm;
}

- (NSUInteger)count {
    return translateErrors([&] { return _backingList.size(); });
}

- (BOOL)isInvalidated {
    return translateErrors([&] { return !_backingList.is_valid(); });
}

- (LEGACYClassInfo *)objectInfo {
    return _objectInfo;
}


- (bool)isBackedByList:(realm::List const&)list {
    return _backingList == list;
}

- (BOOL)isEqual:(id)object {
    return [object respondsToSelector:@selector(isBackedByList:)] && [object isBackedByList:_backingList];
}

- (NSUInteger)hash {
    return std::hash<realm::List>()(_backingList);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return LEGACYFastEnumerate(state, len, self);
}

- (id)objectAtIndex:(NSUInteger)index {
    return translateErrors([&] {
        LEGACYAccessorContext context(*_objectInfo);
        return _backingList.get(context, index);
    });
}

static void LEGACYInsertObject(LEGACYManagedArray *ar, id object, NSUInteger index) {
    LEGACYArrayValidateMatchingObjectType(ar, object);
    if (index == NSUIntegerMax) {
        index = translateErrors([&] { return ar->_backingList.size(); });
    }

    changeArray(ar, NSKeyValueChangeInsertion, index, ^{
        LEGACYAccessorContext context(*ar->_objectInfo);
        ar->_backingList.insert(context, index, object);
    });
}

- (void)addObject:(id)object {
    LEGACYInsertObject(self, object, NSUIntegerMax);
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
    LEGACYInsertObject(self, object, index);
}

- (void)insertObjects:(id<NSFastEnumeration>)objects atIndexes:(NSIndexSet *)indexes {
    changeArray(self, NSKeyValueChangeInsertion, indexes, ^{
        NSUInteger index = [indexes firstIndex];
        LEGACYAccessorContext context(*_objectInfo);
        for (id obj in objects) {
            LEGACYArrayValidateMatchingObjectType(self, obj);
            _backingList.insert(context, index, obj);
            index = [indexes indexGreaterThanIndex:index];
        }
    });
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    changeArray(self, NSKeyValueChangeRemoval, index, ^{
        _backingList.remove(index);
    });
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes {
    changeArray(self, NSKeyValueChangeRemoval, indexes, ^{
        [indexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *) {
            _backingList.remove(idx);
        }];
    });
}

- (void)addObjectsFromArray:(NSArray *)array {
    changeArray(self, NSKeyValueChangeInsertion, NSMakeRange(self.count, array.count), ^{
        LEGACYAccessorContext context(*_objectInfo);
        for (id obj in array) {
            LEGACYArrayValidateMatchingObjectType(self, obj);
            _backingList.add(context, obj);
        }
    });
}

- (void)removeAllObjects {
    changeArray(self, NSKeyValueChangeRemoval, NSMakeRange(0, self.count), ^{
        _backingList.remove_all();
    });
}

- (void)replaceAllObjectsWithObjects:(NSArray *)objects {
    if (auto count = self.count) {
        changeArray(self, NSKeyValueChangeRemoval, NSMakeRange(0, count), ^{
            _backingList.remove_all();
        });
    }
    if (![objects respondsToSelector:@selector(count)] || !objects.count) {
        return;
    }
    changeArray(self, NSKeyValueChangeInsertion, NSMakeRange(0, objects.count), ^{
        LEGACYAccessorContext context(*_objectInfo);
        _backingList.assign(context, objects);
    });
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)object {
    LEGACYArrayValidateMatchingObjectType(self, object);
    changeArray(self, NSKeyValueChangeReplacement, index, ^{
        LEGACYAccessorContext context(*_objectInfo);
        if (index >= _backingList.size()) {
            @throw LEGACYException(@"Index %llu is out of bounds (must be less than %llu).",
                                (unsigned long long)index, (unsigned long long)_backingList.size());
        }
        _backingList.set(context, index, object);
    });
}

- (void)moveObjectAtIndex:(NSUInteger)sourceIndex toIndex:(NSUInteger)destinationIndex {
    auto start = std::min(sourceIndex, destinationIndex);
    auto len = std::max(sourceIndex, destinationIndex) - start + 1;
    changeArray(self, NSKeyValueChangeReplacement, {start, len}, ^{
        _backingList.move(sourceIndex, destinationIndex);
    });
}

- (void)exchangeObjectAtIndex:(NSUInteger)index1 withObjectAtIndex:(NSUInteger)index2 {
    changeArray(self, NSKeyValueChangeReplacement, ^{
        _backingList.swap(index1, index2);
    }, [=] {
        NSMutableIndexSet *set = [[NSMutableIndexSet alloc] initWithIndex:index1];
        [set addIndex:index2];
        return set;
    });
}

- (NSUInteger)indexOfObject:(id)object {
    LEGACYArrayValidateMatchingObjectType(self, object);
    return translateErrors([&] {
        LEGACYAccessorContext context(*_objectInfo);
        return LEGACYConvertNotFound(_backingList.find(context, object));
    });
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) {
        // Delegate KVC collection operators to LEGACYResults
        return translateErrors([&] {
            auto results = [LEGACYResults resultsWithObjectInfo:*_objectInfo results:_backingList.as_results()];
            return [results valueForKeyPath:keyPath];
        });
    }
    return [super valueForKeyPath:keyPath];
}

- (id)valueForKey:(NSString *)key {
    // Ideally we'd use "@invalidated" for this so that "invalidated" would use
    // normal array KVC semantics, but observing @things works very oddly (when
    // it's part of a key path, it's triggered automatically when array index
    // changes occur, and can't be sent explicitly, but works normally when it's
    // the entire key path), and an LEGACYManagedArray *can't* have objects where
    // invalidated is true, so we're not losing much.
    return translateErrors([&]() -> id {
        if ([key isEqualToString:LEGACYInvalidatedKey]) {
            return @(!_backingList.is_valid());
        }

        _backingList.verify_attached();
        return LEGACYCollectionValueForKey(_backingList, key, *_objectInfo);
    });
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"self"]) {
        LEGACYArrayValidateMatchingObjectType(self, value);
        LEGACYAccessorContext context(*_objectInfo);
        translateErrors([&] {
            for (size_t i = 0, count = _backingList.size(); i < count; ++i) {
                _backingList.set(context, i, value);
            }
        });
        return;
    }
    else if (_type == LEGACYPropertyTypeObject) {
        LEGACYArrayValidateMatchingObjectType(self, value);
        translateErrors([&] { _backingList.verify_in_transaction(); });
        LEGACYCollectionSetValueForKey(self, key, value);
    }
    else {
        [self setValue:value forUndefinedKey:key];
    }
}

- (id)minOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingList, _objectInfo, _type, LEGACYCollectionTypeArray);
    auto value = translateErrors([&] { return _backingList.min(column); });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (id)maxOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingList, _objectInfo, _type, LEGACYCollectionTypeArray);
    auto value = translateErrors([&] { return _backingList.max(column); });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (id)sumOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingList, _objectInfo, _type, LEGACYCollectionTypeArray);
    return LEGACYMixedToObjc(translateErrors([&] { return _backingList.sum(column); }));
}

- (id)averageOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingList, _objectInfo, _type, LEGACYCollectionTypeArray);
    auto value = translateErrors([&] { return _backingList.average(column); });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (void)deleteObjectsFromRealm {
    if (_type != LEGACYPropertyTypeObject) {
        @throw LEGACYException(@"Cannot delete objects from LEGACYArray<%@>: only LEGACYObjects can be deleted.", LEGACYTypeToString(_type));
    }
    // delete all target rows from the realm
    LEGACYObservationTracker tracker(_realm, true);
    translateErrors([&] { _backingList.delete_all(); });
}

- (LEGACYResults *)sortedResultsUsingDescriptors:(NSArray<LEGACYSortDescriptor *> *)properties {
    return translateErrors([&] {
        return [LEGACYResults resultsWithObjectInfo:*_objectInfo
                                         results:_backingList.sort(LEGACYSortDescriptorsToKeypathArray(properties))];
    });
}

- (LEGACYResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    return translateErrors([&] {
        auto results = [LEGACYResults resultsWithObjectInfo:*_objectInfo results:_backingList.as_results()];
        return [results distinctResultsUsingKeyPaths:keyPaths];
    });
}

- (LEGACYResults *)objectsWithPredicate:(NSPredicate *)predicate {
    if (_type != LEGACYPropertyTypeObject) {
        @throw LEGACYException(@"Querying is currently only implemented for arrays of Realm Objects");
    }
    auto query = LEGACYPredicateToQuery(predicate, _objectInfo->rlmObjectSchema, _realm.schema, _realm.group);
    auto results = translateErrors([&] { return _backingList.filter(std::move(query)); });
    return [LEGACYResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
}

- (NSUInteger)indexOfObjectWithPredicate:(NSPredicate *)predicate {
    if (_type != LEGACYPropertyTypeObject) {
        @throw LEGACYException(@"Querying is currently only implemented for arrays of Realm Objects");
    }
    realm::Query query = LEGACYPredicateToQuery(predicate, _objectInfo->rlmObjectSchema,
                                             _realm.schema, _realm.group);

    return translateErrors([&] {
        return LEGACYConvertNotFound(_backingList.find(std::move(query)));
    });
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes {
    size_t c = self.count;
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:indexes.count];
    NSUInteger i = [indexes firstIndex];
    LEGACYAccessorContext context(*_objectInfo);
    while (i != NSNotFound) {
        // Given KVO relies on `objectsAtIndexes` we need to make sure
        // that no out of bounds exceptions are generated. This disallows us to mirror
        // the exception logic in Foundation, but it is better than nothing.
        if (i >= 0 && i < c) {
            [result addObject:_backingList.get(context, i)];
        } else {
            // silently abort.
            return nil;
        }
        i = [indexes indexGreaterThanIndex:i];
    }
    return result;
}

- (LEGACYSectionedResults *)sectionedResultsSortedUsingKeyPath:(NSString *)keyPath
                                                  ascending:(BOOL)ascending
                                                   keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock {
    return [[LEGACYSectionedResults alloc] initWithResults:[self sortedResultsUsingKeyPath:keyPath ascending:ascending]
                                               keyBlock:keyBlock];
}

- (LEGACYSectionedResults *)sectionedResultsUsingSortDescriptors:(NSArray<LEGACYSortDescriptor *> *)sortDescriptors
                                                     keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock {
    return [[LEGACYSectionedResults alloc] initWithResults:[self sortedResultsUsingDescriptors:sortDescriptors]
                                               keyBlock:keyBlock];
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    LEGACYEnsureArrayObservationInfo(_observationInfo, keyPath, self, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (realm::TableView)tableView {
    return translateErrors([&] { return _backingList.get_query(); }).find_all();
}

- (LEGACYFastEnumerator *)fastEnumerator {
    return translateErrors([&] {
        return [[LEGACYFastEnumerator alloc] initWithBackingCollection:_backingList
                                                         collection:self
                                                          classInfo:*_objectInfo];
    });
}

- (BOOL)isFrozen {
    return _realm.isFrozen;
}

- (instancetype)resolveInRealm:(LEGACYRealm *)realm {
    auto& parentInfo = _ownerInfo->resolve(realm);
    return translateErrors([&] {
        return [[self.class alloc] initWithBackingCollection:_backingList.freeze(realm->_realm)
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

- (realm::NotificationToken)addNotificationCallback:(id)block
keyPaths:(std::optional<std::vector<std::vector<std::pair<realm::TableKey, realm::ColKey>>>>&&)keyPaths {
    return _backingList.add_notification_callback(LEGACYWrapCollectionChangeCallback(block, self, false), std::move(keyPaths));
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return _backingList;
}

- (LEGACYManagedArrayHandoverMetadata *)objectiveCMetadata {
    LEGACYManagedArrayHandoverMetadata *metadata = [[LEGACYManagedArrayHandoverMetadata alloc] init];
    metadata.parentClassName = _ownerInfo->rlmObjectSchema.className;
    metadata.key = _key;
    return metadata;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(LEGACYManagedArrayHandoverMetadata *)metadata
                                        realm:(LEGACYRealm *)realm {
    auto list = reference.resolve<realm::List>(realm->_realm);
    if (!list.is_valid()) {
        return nil;
    }
    LEGACYClassInfo *parentInfo = &realm->_info[metadata.parentClassName];
    return [[LEGACYManagedArray alloc] initWithBackingCollection:std::move(list)
                                                   parentInfo:parentInfo
                                                     property:parentInfo->rlmObjectSchema[metadata.key]];
}

@end
