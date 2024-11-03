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

#import "LEGACYObjectStore.h"

#import "LEGACYAccessor.hpp"
#import "LEGACYArray_Private.hpp"
#import "LEGACYObservation.hpp"
#import "LEGACYObject_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYSchema_Private.h"
#import "LEGACYSet_Private.hpp"
#import "LEGACYSwiftCollectionBase.h"
#import "LEGACYSwiftSupport.h"
#import "LEGACYUtil.hpp"
#import "LEGACYSwiftValueStorage.h"

#import <realm/object-store/object_store.hpp>
#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/group.hpp>

#import <objc/message.h>

static inline void LEGACYVerifyRealmRead(__unsafe_unretained LEGACYRealm *const realm) {
    if (!realm) {
        @throw LEGACYException(@"Realm must not be nil");
    }
    [realm verifyThread];
    if (realm->_realm->is_closed()) {
        // This message may seem overly specific, but frozen Realms are currently
        // the only ones which we outright close.
        @throw LEGACYException(@"Cannot read from a frozen Realm which has been invalidated.");
    }
}

void LEGACYVerifyInWriteTransaction(__unsafe_unretained LEGACYRealm *const realm) {
    LEGACYVerifyRealmRead(realm);
    // if realm is not writable throw
    if (!realm.inWriteTransaction) {
        @throw LEGACYException(@"Can only add, remove, or create objects in a Realm in a write transaction - call beginWriteTransaction on an LEGACYRealm instance first.");
    }
}

void LEGACYInitializeSwiftAccessor(__unsafe_unretained LEGACYObjectBase *const object, bool promoteExisting) {
    if (!object || !object->_row || !object->_objectSchema->_isSwiftClass) {
        return;
    }
    if (![object isKindOfClass:object->_objectSchema.objectClass]) {
        // It can be a different class if it's a dynamic object, and those don't
        // require any init here (and would crash since they don't have the ivars)
        return;
    }

    if (promoteExisting) {
        for (LEGACYProperty *prop in object->_objectSchema.swiftGenericProperties) {
            [prop.swiftAccessor promote:prop on:object];
        }
    }
    else {
        for (LEGACYProperty *prop in object->_objectSchema.swiftGenericProperties) {
            [prop.swiftAccessor initialize:prop on:object];
        }
    }
}

void LEGACYVerifyHasPrimaryKey(Class cls) {
    LEGACYObjectSchema *schema = [cls sharedSchema];
    if (!schema.primaryKeyProperty) {
        NSString *reason = [NSString stringWithFormat:@"'%@' does not have a primary key and can not be updated", schema.className];
        @throw [NSException exceptionWithName:@"LEGACYException" reason:reason userInfo:nil];
    }
}

using realm::CreatePolicy;
static CreatePolicy updatePolicyToCreatePolicy(LEGACYUpdatePolicy policy) {
    CreatePolicy createPolicy = {.create = true, .copy = false, .diff = false, .update = false};
    switch (policy) {
        case LEGACYUpdatePolicyError:
            break;
        case LEGACYUpdatePolicyUpdateChanged:
            createPolicy.diff = true;
            [[clang::fallthrough]];
        case LEGACYUpdatePolicyUpdateAll:
            createPolicy.update = true;
            break;
    }
    return createPolicy;
}

void LEGACYAddObjectToRealm(__unsafe_unretained LEGACYObjectBase *const object,
                         __unsafe_unretained LEGACYRealm *const realm,
                         LEGACYUpdatePolicy updatePolicy) {
    LEGACYVerifyInWriteTransaction(realm);

    CreatePolicy createPolicy = updatePolicyToCreatePolicy(updatePolicy);
    createPolicy.copy = false;
    auto& info = realm->_info[object->_objectSchema.className];
    LEGACYAccessorContext c{info};
    c.createObject(object, createPolicy);
}

LEGACYObjectBase *LEGACYCreateObjectInRealmWithValue(LEGACYRealm *realm, NSString *className,
                                               id value, LEGACYUpdatePolicy updatePolicy) {
    LEGACYVerifyInWriteTransaction(realm);

    CreatePolicy createPolicy = updatePolicyToCreatePolicy(updatePolicy);
    createPolicy.copy = true;

    auto& info = realm->_info[className];
    LEGACYAccessorContext c{info};
    LEGACYObjectBase *object = LEGACYCreateManagedAccessor(info.rlmObjectSchema.accessorClass, &info);
    auto [obj, reuseExisting] = c.createObject(value, createPolicy, true);
    if (reuseExisting) {
        return value;
    }
    object->_row = std::move(obj);
    LEGACYInitializeSwiftAccessor(object, false);
    return object;
}

void LEGACYCreateAsymmetricObjectInRealm(LEGACYRealm *realm, NSString *className, id value) {
    LEGACYVerifyInWriteTransaction(realm);

    CreatePolicy createPolicy = {.create = true, .copy = true, .diff = false, .update = false};

    auto& info = realm->_info[className];
    LEGACYAccessorContext c{info};
    c.createObject(value, createPolicy);
}

LEGACYObjectBase *LEGACYObjectFromObjLink(LEGACYRealm *realm, realm::ObjLink&& objLink, bool parentIsSwiftObject) {
    if (auto* tableInfo = realm->_info[objLink.get_table_key()]) {
        return LEGACYCreateObjectAccessor(*tableInfo, objLink.get_obj_key().value);
    } else {
        // Construct the object dynamically.
        // This code path should only be hit on first access of the object.
        Class cls = parentIsSwiftObject ? [RealmSwiftDynamicObject class] : [LEGACYDynamicObject class];
        auto& group = realm->_realm->read_group();
        auto schema = std::make_unique<realm::ObjectSchema>(group,
                                                            group.get_table_name(objLink.get_table_key()),
                                                            objLink.get_table_key());
        LEGACYObjectSchema *rlmObjectSchema = [LEGACYObjectSchema objectSchemaForObjectStoreSchema:*schema];
        rlmObjectSchema.accessorClass = cls;
        rlmObjectSchema.isSwiftClass = parentIsSwiftObject;
        realm->_info.appendDynamicObjectSchema(std::move(schema), rlmObjectSchema, realm);
        return LEGACYCreateObjectAccessor(realm->_info[rlmObjectSchema.className], objLink.get_obj_key().value);
    }
}

void LEGACYDeleteObjectFromRealm(__unsafe_unretained LEGACYObjectBase *const object,
                              __unsafe_unretained LEGACYRealm *const realm) {
    if (realm != object->_realm) {
        @throw LEGACYException(@"Can only delete an object from the Realm it belongs to.");
    }

    LEGACYVerifyInWriteTransaction(object->_realm);

    if (object->_row.is_valid()) {
        LEGACYObservationTracker tracker(realm, true);
        object->_row.remove();
    }
    object->_realm = nil;
}

void LEGACYDeleteAllObjectsFromRealm(LEGACYRealm *realm) {
    LEGACYVerifyInWriteTransaction(realm);

    // clear table for each object schema
    for (auto& info : realm->_info) {
        LEGACYClearTable(info.second);
    }
}

LEGACYResults *LEGACYGetObjects(__unsafe_unretained LEGACYRealm *const realm,
                          NSString *objectClassName,
                          NSPredicate *predicate) {
    LEGACYVerifyRealmRead(realm);

    // create view from table and predicate
    LEGACYClassInfo& info = realm->_info[objectClassName];
    if (!info.table()) {
        // read-only realms may be missing tables since we can't add any
        // missing ones on init
        return [LEGACYResults resultsWithObjectInfo:info results:{}];
    }

    if (predicate) {
        realm::Query query = LEGACYPredicateToQuery(predicate, info.rlmObjectSchema, realm.schema, realm.group);
        return [LEGACYResults resultsWithObjectInfo:info
                                         results:realm::Results(realm->_realm, std::move(query))];
    }

    return [LEGACYResults resultsWithObjectInfo:info
                                     results:realm::Results(realm->_realm, info.table())];
}

id LEGACYGetObject(LEGACYRealm *realm, NSString *objectClassName, id key) {
    LEGACYVerifyRealmRead(realm);

    auto& info = realm->_info[objectClassName];
    if (LEGACYProperty *prop = info.propertyForPrimaryKey()) {
        LEGACYValidateValueForProperty(key, info.rlmObjectSchema, prop);
    }
    try {
        LEGACYAccessorContext c{info};
        auto obj = realm::Object::get_for_primary_key(c, realm->_realm, *info.objectSchema,
                                                      key ?: NSNull.null);
        if (!obj.is_valid())
            return nil;
        return LEGACYCreateObjectAccessor(info, obj.get_obj());
    }
    catch (std::exception const& e) {
        @throw LEGACYException(e);
    }
}

LEGACYObjectBase *LEGACYCreateObjectAccessor(LEGACYClassInfo& info, int64_t key) {
    return LEGACYCreateObjectAccessor(info, info.table()->get_object(realm::ObjKey(key)));
}

// Create accessor and register with realm
LEGACYObjectBase *LEGACYCreateObjectAccessor(LEGACYClassInfo& info, const realm::Obj& obj) {
    LEGACYObjectBase *accessor = LEGACYCreateManagedAccessor(info.rlmObjectSchema.accessorClass, &info);
    accessor->_row = obj;
    LEGACYInitializeSwiftAccessor(accessor, false);
    return accessor;
}
