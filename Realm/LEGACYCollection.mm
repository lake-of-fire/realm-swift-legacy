////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import "LEGACYCollection_Private.hpp"

#import "LEGACYAccessor.hpp"
#import "LEGACYArray_Private.hpp"
#import "LEGACYDictionary_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYObservation.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYSet_Private.hpp"
#import "LEGACYSwiftCollectionBase.h"

#import <realm/object-store/dictionary.hpp>
#import <realm/object-store/list.hpp>
#import <realm/object-store/results.hpp>
#import <realm/object-store/set.hpp>

static const int LEGACYEnumerationBufferSize = 16;

@implementation LEGACYFastEnumerator {
    // The buffer supplied by fast enumeration does not retain the objects given
    // to it, but because we create objects on-demand and don't want them
    // autoreleased (a table can have more rows than the device has memory for
    // accessor objects) we need a thing to retain them.
    id _strongBuffer[LEGACYEnumerationBufferSize];

    LEGACYRealm *_realm;
    LEGACYClassInfo *_info;

    // A pointer to either _snapshot or a Results from the source collection,
    // to avoid having to copy the Results when not in a write transaction
    realm::Results *_results;
    realm::Results _snapshot;

    // A strong reference to the collection being enumerated to ensure it stays
    // alive when we're holding a pointer to a member in it
    id _collection;
}

- (instancetype)initWithBackingCollection:(realm::object_store::Collection const&)backingCollection
                               collection:(id)collection
                                classInfo:(LEGACYClassInfo&)info {
    self = [super init];
    if (self) {
        _info = &info;
        _realm = _info->realm;

        if (_realm.inWriteTransaction) {
            _snapshot = backingCollection.as_results().snapshot();
        }
        else {
            _snapshot = backingCollection.as_results();
            _collection = collection;
            [_realm registerEnumerator:self];
        }
        _results = &_snapshot;
    }
    return self;
}

- (instancetype)initWithBackingDictionary:(realm::object_store::Dictionary const&)backingDictionary
                               dictionary:(LEGACYManagedDictionary *)dictionary
                                classInfo:(LEGACYClassInfo&)info {
    self = [super init];
    if (self) {
        _info = &info;
        _realm = _info->realm;

        if (_realm.inWriteTransaction) {
            _snapshot = backingDictionary.get_keys().snapshot();
        }
        else {
            _snapshot = backingDictionary.get_keys();
            _collection = dictionary;
            [_realm registerEnumerator:self];
        }
        _results = &_snapshot;
    }
    return self;
}

- (instancetype)initWithResults:(realm::Results&)results
                     collection:(id)collection
                      classInfo:(LEGACYClassInfo&)info {
    self = [super init];
    if (self) {
        _info = &info;
        _realm = _info->realm;
        if (_realm.inWriteTransaction) {
            _snapshot = results.snapshot();
            _results = &_snapshot;
        }
        else {
            _results = &results;
            _collection = collection;
            [_realm registerEnumerator:self];
        }
    }
    return self;
}

- (void)dealloc {
    if (_collection) {
        [_realm unregisterEnumerator:self];
    }
}

- (void)detach {
    _snapshot = _results->snapshot();
    _results = &_snapshot;
    _collection = nil;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len {
    [_realm verifyThread];
    if (!_results->is_valid()) {
        @throw LEGACYException(@"Collection is no longer valid");
    }
    // The fast enumeration buffer size is currently a hardcoded number in the
    // compiler so this can't actually happen, but just in case it changes in
    // the future...
    if (len > LEGACYEnumerationBufferSize) {
        len = LEGACYEnumerationBufferSize;
    }

    NSUInteger batchCount = 0, count = state->extra[1];

    @autoreleasepool {
        LEGACYAccessorContext ctx(*_info);
        for (NSUInteger index = state->state; index < count && batchCount < len; ++index) {
            _strongBuffer[batchCount] = _results->get(ctx, index);
            batchCount++;
        }
    }

    for (NSUInteger i = batchCount; i < len; ++i) {
        _strongBuffer[i] = nil;
    }

    if (batchCount == 0) {
        // Release our data if we're done, as we're autoreleased and so may
        // stick around for a while
        if (_collection) {
            _collection = nil;
            [_realm unregisterEnumerator:self];
        }

        _snapshot = {};
    }

    state->itemsPtr = (__unsafe_unretained id *)(void *)_strongBuffer;
    state->state += batchCount;
    state->mutationsPtr = state->extra+1;

    return batchCount;
}
@end

NSUInteger LEGACYFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            id<LEGACYCollectionPrivate> collection) {
    __autoreleasing LEGACYFastEnumerator *enumerator;
    if (state->state == 0) {
        enumerator = collection.fastEnumerator;
        state->extra[0] = (long)enumerator;
        state->extra[1] = collection.count;
    }
    else {
        enumerator = (__bridge id)(void *)state->extra[0];
    }

    return [enumerator countByEnumeratingWithState:state count:len];
}

@interface LEGACYArrayHolder : NSObject
@end
@implementation LEGACYArrayHolder {
    std::unique_ptr<id[]> items;
}

NSUInteger LEGACYUnmanagedFastEnumerate(id collection, NSFastEnumerationState *state) {
    if (state->state != 0) {
        return 0;
    }

    // We need to enumerate a copy of the backing array so that it doesn't
    // reflect changes made during enumeration. This copy has to be autoreleased
    // (since there's nowhere for us to store a strong reference), and uses
    // LEGACYArrayHolder rather than an NSArray because NSArray doesn't guarantee
    // that it'll use a single contiguous block of memory, and if it doesn't
    // we'd need to forward multiple calls to this method to the same NSArray,
    // which would require holding a reference to it somewhere.
    __autoreleasing LEGACYArrayHolder *copy = [[LEGACYArrayHolder alloc] init];
    copy->items = std::make_unique<id[]>([collection count]);

    NSUInteger i = 0;
    for (id object in collection) {
        copy->items[i++] = object;
    }

    state->itemsPtr = (__unsafe_unretained id *)(void *)copy->items.get();
    // needs to point to something valid, but the whole point of this is so
    // that it can't be changed
    state->mutationsPtr = state->extra;
    state->state = i;

    return i;
}
@end

template<typename Collection>
NSArray *LEGACYCollectionValueForKey(Collection& collection, NSString *key, LEGACYClassInfo& info) {
    size_t count = collection.size();
    if (count == 0) {
        return @[];
    }

    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    if ([key isEqualToString:@"self"]) {
        LEGACYAccessorContext context(info);
        for (size_t i = 0; i < count; ++i) {
            [array addObject:collection.get(context, i) ?: NSNull.null];
        }
        return array;
    }

    if (collection.get_type() != realm::PropertyType::Object) {
        LEGACYAccessorContext context(info);
        for (size_t i = 0; i < count; ++i) {
            [array addObject:[collection.get(context, i) valueForKey:key] ?: NSNull.null];
        }
        return array;
    }

    LEGACYObject *accessor = LEGACYCreateManagedAccessor(info.rlmObjectSchema.accessorClass, &info);
    auto prop = info.rlmObjectSchema[key];

    // Collection properties need to be handled specially since we need to create
    // a new collection each time
    if (info.rlmObjectSchema.isSwiftClass) {
        if (prop.collection && prop.swiftAccessor) {
            // Grab the actual class for the generic collection from an instance of it
            // so that we can make instances of the collection without creating a new
            // object accessor each time
            Class cls = [[prop.swiftAccessor get:prop on:accessor] class];
            for (size_t i = 0; i < count; ++i) {
                LEGACYSwiftCollectionBase *base = [[cls alloc] init];
                base._rlmCollection = [[[cls _backingCollectionType] alloc]
                                       initWithParent:collection.get(i) property:prop parentInfo:info];
                [array addObject:base];
            }
            return array;
        }
    }

    auto swiftAccessor = prop.swiftAccessor;
    for (size_t i = 0; i < count; i++) {
        accessor->_row = collection.get(i);
        if (swiftAccessor) {
            [swiftAccessor initialize:prop on:accessor];
        }
        [array addObject:[accessor valueForKey:key] ?: NSNull.null];
    }
    return array;
}

realm::ColKey columnForProperty(NSString *propertyName,
                                realm::object_store::Collection const& backingCollection,
                                LEGACYClassInfo *objectInfo,
                                LEGACYPropertyType propertyType,
                                LEGACYCollectionType collectionType) {
    if (backingCollection.get_type() == realm::PropertyType::Object) {
        return objectInfo->tableColumn(propertyName);
    }
    if (![propertyName isEqualToString:@"self"]) {
        NSString *collectionTypeName;
        switch (collectionType) {
            case LEGACYCollectionTypeArray:
                collectionTypeName = @"Arrays";
                break;
            case LEGACYCollectionTypeSet:
                collectionTypeName = @"Sets";
                break;
            case LEGACYCollectionTypeDictionary:
                collectionTypeName = @"Dictionaries";
                break;
        }
        @throw LEGACYException(@"%@ of '%@' can only be aggregated on \"self\"",
                            collectionTypeName, LEGACYTypeToString(propertyType));
    }
    return {};
}

template NSArray *LEGACYCollectionValueForKey(realm::Results&, NSString *, LEGACYClassInfo&);
template NSArray *LEGACYCollectionValueForKey(realm::List&, NSString *, LEGACYClassInfo&);
template NSArray *LEGACYCollectionValueForKey(realm::object_store::Set&, NSString *, LEGACYClassInfo&);

void LEGACYCollectionSetValueForKey(id<LEGACYCollectionPrivate> collection, NSString *key, id value) {
    realm::TableView tv = [collection tableView];
    if (tv.size() == 0) {
        return;
    }

    LEGACYClassInfo *info = collection.objectInfo;
    LEGACYObject *accessor = LEGACYCreateManagedAccessor(info->rlmObjectSchema.accessorClass, info);
    for (size_t i = 0; i < tv.size(); i++) {
        accessor->_row = tv[i];
        LEGACYInitializeSwiftAccessor(accessor, false);
        [accessor setValue:value forKey:key];
    }
}

void LEGACYAssignToCollection(id<LEGACYCollection> collection, id value) {
    [(id)collection replaceAllObjectsWithObjects:value];
}

NSString *LEGACYDescriptionWithMaxDepth(NSString *name,
                                     id<LEGACYCollection> collection,
                                     NSUInteger depth) {
    if (depth == 0) {
        return @"<Maximum depth exceeded>";
    }

    const NSUInteger maxObjects = 100;
    auto str = [NSMutableString stringWithFormat:@"%@<%@> <%p> (\n", name,
                [collection objectClassName] ?: LEGACYTypeToString([collection type]),
                (void *)collection];
    size_t index = 0, skipped = 0;
    for (id obj in collection) {
        NSString *sub;
        if ([obj respondsToSelector:@selector(descriptionWithMaxDepth:)]) {
            sub = [obj descriptionWithMaxDepth:depth - 1];
        }
        else {
            sub = [obj description];
        }

        // Indent child objects
        NSString *objDescription = [sub stringByReplacingOccurrencesOfString:@"\n"
                                                                  withString:@"\n\t"];
        [str appendFormat:@"\t[%zu] %@,\n", index++, objDescription];
        if (index >= maxObjects) {
            skipped = collection.count - maxObjects;
            break;
        }
    }

    // Remove last comma and newline characters
    if (collection.count > 0) {
        [str deleteCharactersInRange:NSMakeRange(str.length-2, 2)];
    }
    if (skipped) {
        [str appendFormat:@"\n\t... %zu objects skipped.", skipped];
    }
    [str appendFormat:@"\n)"];
    return str;
}

std::vector<std::pair<std::string, bool>> LEGACYSortDescriptorsToKeypathArray(NSArray<LEGACYSortDescriptor *> *properties) {
    std::vector<std::pair<std::string, bool>> keypaths;
    keypaths.reserve(properties.count);
    for (LEGACYSortDescriptor *desc in properties) {
        if ([desc.keyPath rangeOfString:@"@"].location != NSNotFound) {
            @throw LEGACYException(@"Cannot sort on key path '%@': KVC collection operators are not supported.", desc.keyPath);
        }
        keypaths.push_back({desc.keyPath.UTF8String, desc.ascending});
    }
    return keypaths;
}

@implementation LEGACYCollectionChange {
    realm::CollectionChangeSet _indices;
}

- (instancetype)initWithChanges:(realm::CollectionChangeSet)indices {
    self = [super init];
    if (self) {
        _indices = std::move(indices);
    }
    return self;
}

static NSArray *toArray(realm::IndexSet const& set) {
    NSMutableArray *ret = [NSMutableArray new];
    for (auto index : set.as_indexes()) {
        [ret addObject:@(index)];
    }
    return ret;
}

- (NSArray *)insertions {
    return toArray(_indices.insertions);
}

- (NSArray *)deletions {
    return toArray(_indices.deletions);
}

- (NSArray *)modifications {
    return toArray(_indices.modifications);
}

- (NSArray<NSIndexPath *> *)deletionsInSection:(NSUInteger)section {
    return LEGACYToIndexPathArray(_indices.deletions, section);
}

- (NSArray<NSIndexPath *> *)insertionsInSection:(NSUInteger)section {
    return LEGACYToIndexPathArray(_indices.insertions, section);
}

- (NSArray<NSIndexPath *> *)modificationsInSection:(NSUInteger)section {
    return LEGACYToIndexPathArray(_indices.modifications, section);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<LEGACYCollectionChange: %p> insertions: %@, deletions: %@, modifications: %@",
            (__bridge void *)self, self.insertions, self.deletions, self.modifications];
}

@end

namespace {
struct CollectionCallbackWrapper {
    void (^block)(id, id, NSError *);
    id collection;
    bool ignoreChangesInInitialNotification;

    void operator()(realm::CollectionChangeSet const& changes) {
        if (ignoreChangesInInitialNotification) {
            ignoreChangesInInitialNotification = false;
            block(collection, nil, nil);
        }
        else if (changes.empty()) {
            block(collection, nil, nil);
        }
        else if (!changes.collection_root_was_deleted || !changes.deletions.empty()) {
            block(collection, [[LEGACYCollectionChange alloc] initWithChanges:changes], nil);
        }
    }
};
} // anonymous namespace

@interface LEGACYCancellationToken : LEGACYNotificationToken
@end

LEGACY_HIDDEN
@implementation LEGACYCancellationToken {
    __unsafe_unretained LEGACYRealm *_realm;
    realm::NotificationToken _token;
    LEGACYUnfairMutex _mutex;
}

- (LEGACYRealm *)realm {
    std::lock_guard lock(_mutex);
    return _realm;
}

- (void)suppressNextNotification {
    std::lock_guard lock(_mutex);
    if (_realm) {
        _token.suppress_next();
    }
}

- (bool)invalidate {
    std::lock_guard lock(_mutex);
    if (_realm) {
        _token = {};
        _realm = nil;
        return true;
    }
    return false;
}

LEGACYNotificationToken *LEGACYAddNotificationBlock(id c, id block,
                                              NSArray<NSString *> *keyPaths,
                                              dispatch_queue_t queue) {
    id<LEGACYThreadConfined, LEGACYCollectionPrivate> collection = c;
    LEGACYRealm *realm = collection.realm;
    if (!realm) {
        @throw LEGACYException(@"Change notifications are only supported on managed collections.");
    }
    auto token = [[LEGACYCancellationToken alloc] init];
    token->_realm = realm;

    LEGACYClassInfo *info = collection.objectInfo;
    if (!queue) {
        [realm verifyNotificationsAreSupported:true];
        try {
            token->_token = [collection addNotificationCallback:block keyPaths:info->keyPathArrayFromStringArray(keyPaths)];
        }
        catch (const realm::Exception& e) {
            @throw LEGACYException(e);
        }
        return token;
    }

    LEGACYThreadSafeReference *tsr = [LEGACYThreadSafeReference referenceWithThreadConfined:collection];
    LEGACYRealmConfiguration *config = realm.configuration;
    dispatch_async(queue, ^{
        std::lock_guard lock(token->_mutex);
        if (!token->_realm) {
            return;
        }
        LEGACYRealm *realm = token->_realm = [LEGACYRealm realmWithConfiguration:config queue:queue error:nil];
        id collection = [realm resolveThreadSafeReference:tsr];
        token->_token = [collection addNotificationCallback:block keyPaths:info->keyPathArrayFromStringArray(keyPaths)];
    });
    return token;
}

realm::CollectionChangeCallback LEGACYWrapCollectionChangeCallback(void (^block)(id, id, NSError *),
                                                                id collection, bool skipFirst) {
    return CollectionCallbackWrapper{block, collection, skipFirst};
}
@end

NSArray *LEGACYToIndexPathArray(realm::IndexSet const& set, NSUInteger section) {
    NSMutableArray *ret = [NSMutableArray new];
    NSUInteger path[2] = {section, 0};
    for (auto index : set.as_indexes()) {
        path[1] = index;
        [ret addObject:[NSIndexPath indexPathWithIndexes:path length:2]];
    }
    return ret;
}
