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

#import <Realm/LEGACYConstants.h>

#ifdef __cplusplus
extern "C" {
#endif

@class LEGACYRealm, LEGACYSchema, LEGACYObjectBase, LEGACYResults, LEGACYProperty;

typedef NS_ENUM(NSUInteger, LEGACYUpdatePolicy) {
    LEGACYUpdatePolicyError = 1,
    LEGACYUpdatePolicyUpdateChanged = 3,
    LEGACYUpdatePolicyUpdateAll = 2,
};

LEGACY_HEADER_AUDIT_BEGIN(nullability)

void LEGACYVerifyHasPrimaryKey(Class cls);

void LEGACYVerifyInWriteTransaction(LEGACYRealm *const realm);

//
// Adding, Removing, Getting Objects
//

// add an object to the given realm
void LEGACYAddObjectToRealm(LEGACYObjectBase *object, LEGACYRealm *realm, LEGACYUpdatePolicy);

// delete an object from its realm
void LEGACYDeleteObjectFromRealm(LEGACYObjectBase *object, LEGACYRealm *realm);

// deletes all objects from a realm
void LEGACYDeleteAllObjectsFromRealm(LEGACYRealm *realm);

// get objects of a given class
LEGACYResults *LEGACYGetObjects(LEGACYRealm *realm, NSString *objectClassName, NSPredicate * _Nullable predicate)
NS_RETURNS_RETAINED;

// get an object with the given primary key
id _Nullable LEGACYGetObject(LEGACYRealm *realm, NSString *objectClassName, id _Nullable key) NS_RETURNS_RETAINED;

// create object from array or dictionary
LEGACYObjectBase *LEGACYCreateObjectInRealmWithValue(LEGACYRealm *realm, NSString *className,
                                               id _Nullable value, LEGACYUpdatePolicy updatePolicy)
NS_RETURNS_RETAINED;

// creates an asymmetric object and doesn't return
void LEGACYCreateAsymmetricObjectInRealm(LEGACYRealm *realm, NSString *className, id value);

//
// Accessor Creation
//


// Perform the per-property accessor initialization for a managed RealmSwiftLegacyObject
// promotingExisting should be true if the object was previously used as an
// unmanaged object, and false if it is a newly created object.
void LEGACYInitializeSwiftAccessor(LEGACYObjectBase *object, bool promotingExisting);

#ifdef __cplusplus
}

namespace realm {
    class Obj;
    class Table;
    struct ColKey;
    struct ObjLink;
}
class LEGACYClassInfo;

// get an object with a given table & object key
LEGACYObjectBase *LEGACYObjectFromObjLink(LEGACYRealm *realm,
                                    realm::ObjLink&& objLink,
                                    bool parentIsSwiftObject) NS_RETURNS_RETAINED;

// Create accessors
LEGACYObjectBase *LEGACYCreateObjectAccessor(LEGACYClassInfo& info, int64_t key) NS_RETURNS_RETAINED;
LEGACYObjectBase *LEGACYCreateObjectAccessor(LEGACYClassInfo& info, const realm::Obj& obj) NS_RETURNS_RETAINED;
#endif

LEGACY_HEADER_AUDIT_END(nullability)
