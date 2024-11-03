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

#import "LEGACYDictionary_Private.h"

#import "LEGACYCollection_Private.hpp"

#import "LEGACYResults_Private.hpp"

#import <realm/table_ref.hpp>

namespace realm {
    class Results;
}

@class LEGACYObjectBase, LEGACYObjectSchema, LEGACYProperty;
class LEGACYClassInfo;
class LEGACYObservationInfo;

@interface LEGACYDictionary () {
@protected
    NSString *_objectClassName;
    LEGACYPropertyType _type;
    BOOL _optional;
@public
    // The name of the property which this LEGACYDictionary represents
    NSString *_key;
    __weak LEGACYObjectBase *_parentObject;
}
@end

@interface LEGACYManagedDictionary () <LEGACYCollectionPrivate>

- (LEGACYManagedDictionary *)initWithBackingCollection:(realm::object_store::Dictionary)dictionary
                                         parentInfo:(LEGACYClassInfo *)parentInfo
                                           property:(__unsafe_unretained LEGACYProperty *const)property;
- (LEGACYManagedDictionary *)initWithParent:(realm::Obj)parent
                                property:(LEGACYProperty *)property
                              parentInfo:(LEGACYClassInfo&)info;

- (bool)isBackedByDictionary:(realm::object_store::Dictionary const&)dictionary;

// deletes all objects in the LEGACYDictionary from their containing realms
- (void)deleteObjectsFromRealm;
@end

void LEGACYDictionaryValidateObservationKey(__unsafe_unretained NSString *const keyPath,
                                         __unsafe_unretained LEGACYDictionary *const collection);

// Initialize the observation info for an dictionary if needed
void LEGACYEnsureDictionaryObservationInfo(std::unique_ptr<LEGACYObservationInfo>& info,
                                        NSString *keyPath, LEGACYDictionary *array, id observed);
