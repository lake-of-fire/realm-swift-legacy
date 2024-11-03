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

#import "LEGACYObject_Private.h"

#import "LEGACYSwiftObject.h"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/obj.hpp>

class LEGACYObservationInfo;

// LEGACYObject accessor and read/write realm
@interface LEGACYObjectBase () {
    @public
    realm::Obj _row;
    LEGACYObservationInfo *_observationInfo;
    LEGACYClassInfo *_info;
}
@end

id LEGACYCreateManagedAccessor(Class cls, LEGACYClassInfo *info) NS_RETURNS_RETAINED;

// throw an exception if the object is invalidated or on the wrong thread
static inline void LEGACYVerifyAttached(__unsafe_unretained LEGACYObjectBase *const obj) {
    if (!obj->_row.is_valid()) {
        @throw LEGACYException(@"Object has been deleted or invalidated.");
    }
    [obj->_realm verifyThread];
}

// throw an exception if the object can't be modified for any reason
static inline void LEGACYVerifyInWriteTransaction(__unsafe_unretained LEGACYObjectBase *const obj) {
    // first verify is attached
    LEGACYVerifyAttached(obj);

    if (!obj->_realm.inWriteTransaction) {
        if (obj->_realm.isFrozen) {
            @throw LEGACYException(@"Attempting to modify a frozen object - call thaw on the Object instance first.");
        }
        @throw LEGACYException(@"Attempting to modify object outside of a write transaction - call beginWriteTransaction on an LEGACYRealm instance first.");
    }
}

[[clang::objc_runtime_visible]]
@interface RealmSwiftDynamicObject : RealmSwiftObject
@end
