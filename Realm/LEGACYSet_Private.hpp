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

#import "LEGACYSet_Private.h"

#import "LEGACYCollection_Private.hpp"

#import "LEGACYResults_Private.hpp"

namespace realm {
class SetBase;
class CollectionBase;
    namespace object_store {
        class Set;
    }
}

@class LEGACYObjectBase, LEGACYObjectSchema, LEGACYProperty;
class LEGACYClassInfo;
class LEGACYObservationInfo;

@interface LEGACYSet () {
@protected
    NSString *_objectClassName;
    LEGACYPropertyType _type;
    BOOL _optional;
@public
    // The name of the property which this LEGACYSet represents
    NSString *_key;
    __weak LEGACYObjectBase *_parentObject;
}
@end

@interface LEGACYManagedSet () <LEGACYCollectionPrivate>

- (LEGACYManagedSet *)initWithBackingCollection:(realm::object_store::Set)set
                                  parentInfo:(LEGACYClassInfo *)parentInfo
                                    property:(__unsafe_unretained LEGACYProperty *const)property;

- (bool)isBackedBySet:(realm::object_store::Set const&)set;

// deletes all objects in the LEGACYSet from their containing realms
- (void)deleteObjectsFromRealm;

@end

void LEGACYValidateSetObservationKey(NSString *keyPath, LEGACYSet *set);

// Initialize the observation info for a set if needed
void LEGACYEnsureSetObservationInfo(std::unique_ptr<LEGACYObservationInfo>& info,
                                 NSString *keyPath, LEGACYSet *set, id observed);
