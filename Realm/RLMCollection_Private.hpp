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

#import <Realm/LEGACYCollection_Private.h>

#import <Realm/LEGACYRealm.h>

#import <realm/keys.hpp>
#import <realm/object-store/collection_notifications.hpp>

#import <vector>
#import <mutex>

namespace realm {
class CollectionChangeCallback;
class List;
class Obj;
class Results;
class TableView;
struct CollectionChangeSet;
struct ColKey;
namespace object_store {
class Collection;
class Dictionary;
class Set;
}
}
class LEGACYClassInfo;
@class LEGACYFastEnumerator, LEGACYManagedArray, LEGACYManagedSet, LEGACYManagedDictionary, LEGACYProperty, LEGACYObjectBase;

LEGACY_HIDDEN_BEGIN

@protocol LEGACYCollectionPrivate
@property (nonatomic, readonly) LEGACYRealm *realm;
@property (nonatomic, readonly) LEGACYClassInfo *objectInfo;
@property (nonatomic, readonly) NSUInteger count;

- (realm::TableView)tableView;
- (LEGACYFastEnumerator *)fastEnumerator;
- (realm::NotificationToken)addNotificationCallback:(id)block
keyPaths:(std::optional<std::vector<std::vector<std::pair<realm::TableKey, realm::ColKey>>>>&&)keyPaths;
@end

// An object which encapsulates the shared logic for fast-enumerating LEGACYArray
// LEGACYSet and LEGACYResults, and has a buffer to store strong references to the current
// set of enumerated items
LEGACY_DIRECT_MEMBERS
@interface LEGACYFastEnumerator : NSObject
- (instancetype)initWithBackingCollection:(realm::object_store::Collection const&)backingCollection
                               collection:(id)collection
                                classInfo:(LEGACYClassInfo&)info;

- (instancetype)initWithBackingDictionary:(realm::object_store::Dictionary const&)backingDictionary
                               dictionary:(LEGACYManagedDictionary *)dictionary
                                classInfo:(LEGACYClassInfo&)info;

- (instancetype)initWithResults:(realm::Results&)results
                     collection:(id)collection
                      classInfo:(LEGACYClassInfo&)info;

// Detach this enumerator from the source collection. Must be called before the
// source collection is changed.
- (void)detach;

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len;
@end
NSUInteger LEGACYFastEnumerate(NSFastEnumerationState *state, NSUInteger len, id<LEGACYCollectionPrivate> collection);

@interface LEGACYNotificationToken ()
- (void)suppressNextNotification;
- (LEGACYRealm *)realm;
@end

@interface LEGACYCollectionChange ()
- (instancetype)initWithChanges:(realm::CollectionChangeSet)indices;
@end

realm::CollectionChangeCallback LEGACYWrapCollectionChangeCallback(void (^block)(id, id, NSError *),
                                                                id collection, bool skipFirst);

template<typename Collection>
NSArray *LEGACYCollectionValueForKey(Collection& collection, NSString *key, LEGACYClassInfo& info);

std::vector<std::pair<std::string, bool>> LEGACYSortDescriptorsToKeypathArray(NSArray<LEGACYSortDescriptor *> *properties);

realm::ColKey columnForProperty(NSString *propertyName,
                                realm::object_store::Collection const& backingCollection,
                                LEGACYClassInfo *objectInfo,
                                LEGACYPropertyType propertyType,
                                LEGACYCollectionType collectionType);

static inline bool canAggregate(LEGACYPropertyType type, bool allowDate) {
    switch (type) {
        case LEGACYPropertyTypeInt:
        case LEGACYPropertyTypeFloat:
        case LEGACYPropertyTypeDouble:
        case LEGACYPropertyTypeDecimal128:
        case LEGACYPropertyTypeAny:
            return true;
        case LEGACYPropertyTypeDate:
            return allowDate;
        default:
            return false;
    }
}

NSArray *LEGACYToIndexPathArray(realm::IndexSet const& set, NSUInteger section);

LEGACY_HIDDEN_END
