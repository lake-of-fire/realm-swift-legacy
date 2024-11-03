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

#import "LEGACYArray_Private.h"

#import "LEGACYCollection_Private.hpp"

#import "LEGACYResults_Private.hpp"

#import <realm/table_ref.hpp>

namespace realm {
    class Results;
}

@class LEGACYObjectBase, LEGACYObjectSchema, LEGACYProperty;
class LEGACYClassInfo;
class LEGACYObservationInfo;

@interface LEGACYArray () {
@protected
    NSString *_objectClassName;
    LEGACYPropertyType _type;
    BOOL _optional;
@public
    // The name of the property which this LEGACYArray represents
    NSString *_key;
    __weak LEGACYObjectBase *_parentObject;
}
@end

@interface LEGACYManagedArray () <LEGACYCollectionPrivate>
- (LEGACYManagedArray *)initWithBackingCollection:(realm::List)list
                                    parentInfo:(LEGACYClassInfo *)parentInfo
                                      property:(LEGACYProperty *)property;
- (LEGACYManagedArray *)initWithParent:(realm::Obj)parent
                           property:(LEGACYProperty *)property
                         parentInfo:(LEGACYClassInfo&)info;

- (bool)isBackedByList:(realm::List const&)list;

// deletes all objects in the LEGACYArray from their containing realms
- (void)deleteObjectsFromRealm;
@end

void LEGACYValidateArrayObservationKey(NSString *keyPath, LEGACYArray *array);

// Initialize the observation info for an array if needed
void LEGACYEnsureArrayObservationInfo(std::unique_ptr<LEGACYObservationInfo>& info,
                                   NSString *keyPath, LEGACYArray *array, id observed);
