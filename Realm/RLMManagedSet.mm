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

#import "LEGACYAccessor.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYObservation.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYSchema.h"
#import "LEGACYSectionedResults_Private.hpp"
#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/collection.hpp>
#import <realm/object-store/set.hpp>
#import <realm/set.hpp>

#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>

@interface LEGACYManagedSetHandoverMetadata : NSObject
@property (nonatomic) NSString *parentClassName;
@property (nonatomic) NSString *key;
@end

@implementation LEGACYManagedSetHandoverMetadata
@end

@interface LEGACYManagedSet () <LEGACYThreadConfined_Private>
@end

//
// LEGACYSet implementation
//
@implementation LEGACYManagedSet {
@public
    realm::object_store::Set _backingSet;
    LEGACYRealm *_realm;
    LEGACYClassInfo *_objectInfo;
    LEGACYClassInfo *_ownerInfo;
    std::unique_ptr<LEGACYObservationInfo> _observationInfo;
}

- (LEGACYManagedSet *)initWithBackingCollection:(realm::object_store::Set)set
                                  parentInfo:(LEGACYClassInfo *)parentInfo
                                    property:(__unsafe_unretained LEGACYProperty *const)property {
    if (property.type == LEGACYPropertyTypeObject)
        self = [self initWithObjectClassName:property.objectClassName];
    else
        self = [self initWithObjectType:property.type
                               optional:property.optional];
    if (self) {
        _realm = parentInfo->realm;
        REALM_ASSERT(set.get_realm() == _realm->_realm);
        _backingSet = std::move(set);
        _ownerInfo = parentInfo;
        if (property.type == LEGACYPropertyTypeObject)
            _objectInfo = &parentInfo->linkTargetType(property.index);
        else
            _objectInfo = _ownerInfo;
        _key = property.name;
    }
    return self;
}

- (LEGACYManagedSet *)initWithParent:(__unsafe_unretained LEGACYObjectBase *const)parentObject
                         property:(__unsafe_unretained LEGACYProperty *const)property {
    __unsafe_unretained LEGACYRealm *const realm = parentObject->_realm;
    auto col = parentObject->_info->tableColumn(property);
    return [self initWithBackingCollection:realm::object_store::Set(realm->_realm, parentObject->_row, col)
                                parentInfo:parentObject->_info
                                  property:property];
}

- (LEGACYManagedSet *)initWithParent:(realm::Obj)parent
                         property:(__unsafe_unretained LEGACYProperty *const)property
                       parentInfo:(LEGACYClassInfo&)info {
    auto col = info.tableColumn(property);
    return [self initWithBackingCollection:realm::object_store::Set(info.realm->_realm, parent, col)
                                parentInfo:&info
                                  property:property];
}

void LEGACYValidateSetObservationKey(__unsafe_unretained NSString *const keyPath,
                                  __unsafe_unretained LEGACYSet *const set) {
    if (![keyPath isEqualToString:LEGACYInvalidatedKey]) {
        @throw LEGACYException(@"[<%@ %p> addObserver:forKeyPath:options:context:] is not supported. Key path: %@",
                            [set class], set, keyPath);
    }
}

void LEGACYEnsureSetObservationInfo(std::unique_ptr<LEGACYObservationInfo>& info,
                                   __unsafe_unretained NSString *const keyPath,
                                   __unsafe_unretained LEGACYSet *const set,
                                   __unsafe_unretained id const observed) {
    LEGACYValidateSetObservationKey(keyPath, set);
    if (!info && set.class == [LEGACYManagedSet class]) {
        auto lv = static_cast<LEGACYManagedSet *>(set);
        info = std::make_unique<LEGACYObservationInfo>(*lv->_ownerInfo,
                                                    lv->_backingSet.get_parent_object_key(),
                                                    observed);
    }
}

template<typename Function>
__attribute__((always_inline))
static auto translateErrors(Function&& f) {
    return translateCollectionError(static_cast<Function&&>(f), @"Set");
}

static void changeSet(__unsafe_unretained LEGACYManagedSet *const set,
                      dispatch_block_t f) {
    translateErrors([&] { set->_backingSet.verify_in_transaction(); });

    LEGACYObservationTracker tracker(set->_realm, false);
    tracker.trackDeletions();
    auto obsInfo = LEGACYGetObservationInfo(set->_observationInfo.get(),
                                         set->_backingSet.get_parent_object_key(),
                                         *set->_ownerInfo);
    if (obsInfo) {
        tracker.willChange(obsInfo, set->_key);
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
    return translateErrors([&] { return _backingSet.size(); });
}

- (NSArray<id> *)allObjects {
    NSMutableArray *arr = [NSMutableArray new];
    for (id prop : self) {
        [arr addObject:prop];
    }
    return arr;
}

- (BOOL)isInvalidated {
    return translateErrors([&] { return !_backingSet.is_valid(); });
}

- (LEGACYClassInfo *)objectInfo {
    return _objectInfo;
}


- (bool)isBackedBySet:(realm::object_store::Set const&)set {
    return _backingSet == set;
}

- (BOOL)isEqual:(id)object {
    return [object respondsToSelector:@selector(isBackedBySet:)] && [object isBackedBySet:_backingSet];
}

- (NSUInteger)hash {
    return std::hash<realm::object_store::Set>()(_backingSet);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return LEGACYFastEnumerate(state, len, self);
}

static void LEGACYInsertObject(LEGACYManagedSet *set, id object) {
    LEGACYSetValidateMatchingObjectType(set, object);
    changeSet(set, ^{
        LEGACYAccessorContext context(*set->_objectInfo);
        set->_backingSet.insert(context, object);
    });
}

static void LEGACYRemoveObject(LEGACYManagedSet *set, id object) {
    LEGACYSetValidateMatchingObjectType(set, object);
    changeSet(set, ^{
        LEGACYAccessorContext context(*set->_objectInfo);
        set->_backingSet.remove(context, object);
    });
}

static void ensureInWriteTransaction(NSString *message, LEGACYManagedSet *set, LEGACYManagedSet *otherSet) {
    if (!set.realm.inWriteTransaction && !otherSet.realm.inWriteTransaction) {
        @throw LEGACYException(@"Can only perform %@ in a Realm in a write transaction - call beginWriteTransaction on an LEGACYRealm instance first.", message);
    }
}

- (void)addObject:(id)object {
    LEGACYInsertObject(self, object);
}

- (void)addObjects:(id<NSFastEnumeration>)objects {
    changeSet(self, ^{
        LEGACYAccessorContext context(*_objectInfo);
        for (id obj in objects) {
            LEGACYSetValidateMatchingObjectType(self, obj);
            _backingSet.insert(context, obj);
        }
    });
}

- (void)removeObject:(id)object {
    LEGACYRemoveObject(self, object);
}

- (void)removeAllObjects {
    changeSet(self, ^{
        _backingSet.remove_all();
    });
}

- (void)replaceAllObjectsWithObjects:(NSArray *)objects {
    changeSet(self, ^{
        LEGACYAccessorContext context(*_objectInfo);
        _backingSet.assign(context, objects);
    });
}

- (LEGACYManagedSet *)managedObjectFrom:(LEGACYSet *)set {
    auto managedSet = LEGACYDynamicCast<LEGACYManagedSet>(set);
    if (!managedSet) {
        @throw LEGACYException(@"Right hand side value must be a managed Set.");
    }
    if (_type != managedSet->_type) {
        @throw LEGACYException(@"Cannot intersect sets of type '%@' and '%@'.",
                            LEGACYTypeToString(_type), LEGACYTypeToString(managedSet->_type));
    }
    if (_realm != managedSet->_realm) {
        @throw LEGACYException(@"Cannot insersect sets managed by different Realms.");
    }
    if (_objectInfo != managedSet->_objectInfo) {
        @throw LEGACYException(@"Cannot intersect sets of type '%@' and '%@'.",
                            _objectInfo->rlmObjectSchema.className,
                            managedSet->_objectInfo->rlmObjectSchema.className);

    }
    return managedSet;
}

- (BOOL)isSubsetOfSet:(LEGACYSet<id> *)set {
    LEGACYManagedSet *rhs = [self managedObjectFrom:set];
    return _backingSet.is_subset_of(rhs->_backingSet);
}

- (BOOL)intersectsSet:(LEGACYSet<id> *)set {
    LEGACYManagedSet *rhs = [self managedObjectFrom:set];
    return _backingSet.intersects(rhs->_backingSet);
}

- (BOOL)containsObject:(id)obj {
    LEGACYSetValidateMatchingObjectType(self, obj);
    LEGACYAccessorContext context(*_objectInfo);
    auto r = _backingSet.find(context, obj);
    return r != realm::npos;
}

- (BOOL)isEqualToSet:(LEGACYSet<id> *)set {
    LEGACYManagedSet *rhs = [self managedObjectFrom:set];
    return [self isEqual:rhs];
}

- (void)setSet:(LEGACYSet<id> *)set {
    LEGACYManagedSet *rhs = [self managedObjectFrom:set];
    ensureInWriteTransaction(@"[LEGACYSet setSet:]", self, rhs);
    changeSet(self, ^{
        LEGACYAccessorContext context(*_objectInfo);
        _backingSet.assign(context, rhs);
    });
}

- (void)intersectSet:(LEGACYSet<id> *)set {
    LEGACYManagedSet *rhs = [self managedObjectFrom:set];
    ensureInWriteTransaction(@"[LEGACYSet intersectSet:]", self, rhs);
    changeSet(self, ^{
        _backingSet.assign_intersection(rhs->_backingSet);
    });
}

- (void)unionSet:(LEGACYSet<id> *)set {
    LEGACYManagedSet *rhs = [self managedObjectFrom:set];
    ensureInWriteTransaction(@"[LEGACYSet unionSet:]", self, rhs);
    changeSet(self, ^{
        _backingSet.assign_union(rhs->_backingSet);
    });
}

- (void)minusSet:(LEGACYSet<id> *)set {
    LEGACYManagedSet *rhs = [self managedObjectFrom:set];
    ensureInWriteTransaction(@"[LEGACYSet minusSet:]", self, rhs);
    changeSet(self, ^{
        _backingSet.assign_difference(rhs->_backingSet);
    });
}

- (id)objectAtIndex:(NSUInteger)index {
    return translateErrors([&] {
        LEGACYAccessorContext context(*_objectInfo);
        return _backingSet.get(context, index);
    });
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes {
    size_t count = self.count;
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:indexes.count];
    LEGACYAccessorContext context(*_objectInfo);
    for (NSUInteger i = indexes.firstIndex; i != NSNotFound; i = [indexes indexGreaterThanIndex:i]) {
        if (i >= count) {
            return nil;
        }
        [result addObject:_backingSet.get(context, i)];
    }
    return result;
}

- (id)firstObject {
    return translateErrors([&] {
        LEGACYAccessorContext context(*_objectInfo);
        return _backingSet.size() ? _backingSet.get(context, 0) : nil;
    });
}

- (id)lastObject {
    return translateErrors([&] {
        LEGACYAccessorContext context(*_objectInfo);
        size_t size = _backingSet.size();
        return size ? _backingSet.get(context, size - 1) : nil;
    });
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) {
        // Delegate KVC collection operators to LEGACYResults
        return translateErrors([&] {
            auto results = [LEGACYResults resultsWithObjectInfo:*_objectInfo results:_backingSet.as_results()];
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
    // the entire key path), and an LEGACYManagedSet *can't* have objects where
    // invalidated is true, so we're not losing much.
    return translateErrors([&]() -> id {
        if ([key isEqualToString:LEGACYInvalidatedKey]) {
            return @(!_backingSet.is_valid());
        }

        _backingSet.verify_attached();
        return  [NSSet setWithArray:LEGACYCollectionValueForKey(_backingSet, key, *_objectInfo)];
    });
    return nil;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"self"]) {
        LEGACYSetValidateMatchingObjectType(self, value);
        LEGACYAccessorContext context(*_objectInfo);
        translateErrors([&] {
            _backingSet.remove_all();
            _backingSet.insert(context, value);
            return;
        });
    } else if (_type == LEGACYPropertyTypeObject) {
        LEGACYSetValidateMatchingObjectType(self, value);
        translateErrors([&] { _backingSet.verify_in_transaction(); });
        LEGACYCollectionSetValueForKey(self, key, value);
    }
    else {
        [self setValue:value forUndefinedKey:key];
    }
}

- (id)minOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingSet, _objectInfo, _type, LEGACYCollectionTypeSet);
    auto value = translateErrors([&] { return _backingSet.min(column); });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (id)maxOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingSet, _objectInfo, _type, LEGACYCollectionTypeSet);
    auto value = translateErrors([&] { return _backingSet.max(column); });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (id)sumOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingSet, _objectInfo, _type, LEGACYCollectionTypeSet);
    return LEGACYMixedToObjc(translateErrors([&] { return _backingSet.sum(column); }));
}

- (id)averageOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingSet, _objectInfo, _type, LEGACYCollectionTypeSet);
    auto value = translateErrors([&] { return _backingSet.average(column); });
    return value ? LEGACYMixedToObjc(*value) : nil;
}

- (void)deleteObjectsFromRealm {
    if (_type != LEGACYPropertyTypeObject) {
        @throw LEGACYException(@"Cannot delete objects from LEGACYSet<%@>: only LEGACYObjects can be deleted.", LEGACYTypeToString(_type));
    }
    // delete all target rows from the realm
    LEGACYObservationTracker tracker(_realm, true);
    translateErrors([&] { _backingSet.delete_all(); });
}

- (LEGACYResults *)sortedResultsUsingDescriptors:(NSArray<LEGACYSortDescriptor *> *)properties {
    return translateErrors([&] {
        return [LEGACYResults  resultsWithObjectInfo:*_objectInfo
                                          results:_backingSet.sort(LEGACYSortDescriptorsToKeypathArray(properties))];
    });
}

- (LEGACYResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    return translateErrors([&] {
        auto results = [LEGACYResults resultsWithObjectInfo:*_objectInfo results:_backingSet.as_results()];
        return [results distinctResultsUsingKeyPaths:keyPaths];
    });
}

- (LEGACYResults *)objectsWithPredicate:(NSPredicate *)predicate {
    if (_type != LEGACYPropertyTypeObject) {
        @throw LEGACYException(@"Querying is currently only implemented for sets of Realm Objects");
    }
    auto query = LEGACYPredicateToQuery(predicate, _objectInfo->rlmObjectSchema, _realm.schema, _realm.group);
    auto results = translateErrors([&] { return _backingSet.filter(std::move(query)); });
    return [LEGACYResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
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
    LEGACYEnsureSetObservationInfo(_observationInfo, keyPath, self, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (LEGACYFastEnumerator *)fastEnumerator {
    return translateErrors([&] {
        return [[LEGACYFastEnumerator alloc] initWithBackingCollection:_backingSet
                                                         collection:self
                                                          classInfo:*_objectInfo];
    });
}

- (realm::TableView)tableView {
    return translateErrors([&] { return _backingSet.get_query(); }).find_all();
}

- (BOOL)isFrozen {
    return _realm.isFrozen;
}

- (instancetype)resolveInRealm:(LEGACYRealm *)realm {
    auto& parentInfo = _ownerInfo->resolve(realm);
    return translateErrors([&] {
        return [[self.class alloc] initWithBackingCollection:_backingSet.freeze(realm->_realm)
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
    return _backingSet.add_notification_callback(LEGACYWrapCollectionChangeCallback(block, self, false), std::move(keyPaths));
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return _backingSet;
}

- (LEGACYManagedSetHandoverMetadata *)objectiveCMetadata {
    LEGACYManagedSetHandoverMetadata *metadata = [[LEGACYManagedSetHandoverMetadata alloc] init];
    metadata.parentClassName = _ownerInfo->rlmObjectSchema.className;
    metadata.key = _key;
    return metadata;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(LEGACYManagedSetHandoverMetadata *)metadata
                                        realm:(LEGACYRealm *)realm {
    auto set = reference.resolve<realm::object_store::Set>(realm->_realm);
    if (!set.is_valid()) {
        return nil;
    }
    LEGACYClassInfo *parentInfo = &realm->_info[metadata.parentClassName];
    return [[LEGACYManagedSet alloc] initWithBackingCollection:std::move(set)
                                                 parentInfo:parentInfo
                                                   property:parentInfo->rlmObjectSchema[metadata.key]];
}

@end

