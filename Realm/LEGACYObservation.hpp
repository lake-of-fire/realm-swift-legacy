////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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

#import <Foundation/Foundation.h>

#import <realm/obj.hpp>
#import <realm/object-store/binding_context.hpp>
#import <realm/object-store/impl/deep_change_checker.hpp>
#import <realm/table.hpp>

@class LEGACYObjectBase, LEGACYRealm, LEGACYSchema, LEGACYProperty, LEGACYObjectSchema;
class LEGACYClassInfo;
class LEGACYSchemaInfo;

namespace realm {
    class History;
    class SharedGroup;
    struct TableKey;
    struct ColKey;
}

// LEGACYObservationInfo stores all of the KVO-related data for LEGACYObjectBase and
// LEGACYSet/Array. There is a one-to-one relationship between observed objects and
// LEGACYObservationInfo instances, so it could be folded into LEGACYObjectBase, and
// is a separate class mostly to avoid making all accessor objects far larger.
//
// LEGACYClassInfo stores a vector of pointers to the first observation info
// created for each row. If there are multiple observation infos for a single
// row (such as if there are multiple observed objects backed by a single row,
// or if both an object and an array property of that object are observed),
// they're stored in an intrusive doubly-linked-list in the `next` and `prev`
// members. This is done primarily to make it simpler and faster to loop over
// all of the observed objects for a single row, as that needs to be done for
// every change.
class LEGACYObservationInfo {
public:
    LEGACYObservationInfo(id object);
    LEGACYObservationInfo(LEGACYClassInfo &objectSchema, realm::ObjKey row, id object);
    ~LEGACYObservationInfo();

    realm::Obj const& getRow() const {
        return row;
    }

    NSString *columnName(realm::ColKey col) const noexcept;

    // Send willChange/didChange notifications to all observers for this object/row
    // Sends the array versions if indexes is non-nil, normal versions otherwise
    void willChange(NSString *key, NSKeyValueChange kind=NSKeyValueChangeSetting, NSIndexSet *indexes=nil) const;
    void didChange(NSString *key, NSKeyValueChange kind=NSKeyValueChangeSetting, NSIndexSet *indexes=nil) const;

    bool isForRow(realm::ObjKey key) const {
        return row.get_key() == key;
    }

    void recordObserver(realm::Obj& row, LEGACYClassInfo *objectInfo, LEGACYObjectSchema *objectSchema, NSString *keyPath);
    void removeObserver();
    bool hasObservers() const { return observerCount > 0; }

    // valueForKey: on observed object and array properties needs to return the
    // same object each time for KVO to work at all. Doing this all the time
    // requires some odd semantics to avoid reference cycles, so instead we do
    // it only to the extent specifically required by KVO. In addition, we
    // need to continue to return the same object even if this row is deleted,
    // or deleting an object with active observers will explode horribly.
    // Once prepareForInvalidation() is called, valueForKey() will always return
    // the cached value for object and array properties without checking the
    // backing row to verify it's up-to-date.
    //
    // prepareForInvalidation() must be called on the head of the linked list
    // (i.e. on the object pointed to directly by the object schema)
    id valueForKey(NSString *key);

    void prepareForInvalidation();

private:
    // Doubly-linked-list of observed objects for the same row as this
    LEGACYObservationInfo *next = nullptr;
    LEGACYObservationInfo *prev = nullptr;

    // Row being observed
    realm::Obj row;
    LEGACYClassInfo *objectSchema = nullptr;

    // Object doing the observing
    __unsafe_unretained id object = nil;

    // valueForKey: hack
    bool invalidated = false;
    size_t observerCount = 0;
    NSString *lastKey = nil;
    __unsafe_unretained LEGACYProperty *lastProp = nil;

    // objects returned from valueForKey() to keep them alive in case observers
    // are added and so that they can still be accessed after row is detached
    NSMutableDictionary *cachedObjects;

    void setRow(realm::Table const& table, realm::ObjKey newRow);

    template<typename F>
    void forEach(F&& f) const {
        // The user's observation handler may release their last reference to
        // the object being observed, which will result in the LEGACYObservationInfo
        // being destroyed. As a result, we need to retain the object which owns
        // both `this` and the current info we're looking at.
        __attribute__((objc_precise_lifetime)) id self = object, current;
        for (auto info = prev; info; info = info->prev) {
            current = info->object;
            f(info->object);
        }
        for (auto info = this; info; info = info->next) {
            current = info->object;
            f(info->object);
        }
    }

    // Default move/copy constructors don't work due to the intrusive linked
    // list and we don't need them
    LEGACYObservationInfo(LEGACYObservationInfo const&) = delete;
    LEGACYObservationInfo(LEGACYObservationInfo&&) = delete;
    LEGACYObservationInfo& operator=(LEGACYObservationInfo const&) = delete;
    LEGACYObservationInfo& operator=(LEGACYObservationInfo&&) = delete;
};

// Get the the observation info chain for the given row
// Will simply return info if it's non-null, and will search ojectSchema's array
// for a matching one otherwise, and return null if there are none
LEGACYObservationInfo *LEGACYGetObservationInfo(LEGACYObservationInfo *info, realm::ObjKey row, LEGACYClassInfo& objectSchema);

// delete all objects from a single table with change notifications
void LEGACYClearTable(LEGACYClassInfo &realm);

class LEGACYObservationTracker {
public:
    LEGACYObservationTracker(LEGACYRealm *realm, bool trackDeletions=false);
    ~LEGACYObservationTracker();

    void trackDeletions();

    void willChange(LEGACYObservationInfo *info, NSString *key,
                    NSKeyValueChange kind=NSKeyValueChangeSetting,
                    NSIndexSet *indexes=nil);
    void didChange();

private:
    std::vector<std::vector<LEGACYObservationInfo *> *> _observedTables;
    __unsafe_unretained LEGACYRealm const*_realm;
    realm::Group& _group;
    LEGACYObservationInfo *_info = nullptr;

    NSString *_key;
    NSKeyValueChange _kind = NSKeyValueChangeSetting;
    NSIndexSet *_indexes;

    struct Change {
        LEGACYObservationInfo *info;
        __unsafe_unretained NSString *property;
        NSMutableIndexSet *indexes;
    };
    std::vector<Change> _changes;
    std::vector<LEGACYObservationInfo *> _invalidated;

    template<typename CascadeNotification>
    void cascadeNotification(CascadeNotification const&);
};

std::vector<realm::BindingContext::ObserverState> LEGACYGetObservedRows(LEGACYSchemaInfo const& schema);
void LEGACYWillChange(std::vector<realm::BindingContext::ObserverState> const& observed, std::vector<void *> const& invalidated);
void LEGACYDidChange(std::vector<realm::BindingContext::ObserverState> const& observed, std::vector<void *> const& invalidated);

// Used for checking if an `Object` declared with `@StateRealmObject` needs to have
// it's accessors temporarily removed and added back so that the `Object` can be
// managed be the Realm.
[[clang::objc_runtime_visible]]
@interface LEGACYSwiftUIKVO : NSObject
+ (BOOL)removeObserversFromObject:(NSObject *)object;
+ (void)addObserversToObject:(NSObject *)object;
@end
