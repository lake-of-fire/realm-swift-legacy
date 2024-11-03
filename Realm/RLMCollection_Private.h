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

#import <Realm/LEGACYCollection.h>

@protocol LEGACYCollectionPrivate;

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

NSUInteger LEGACYUnmanagedFastEnumerate(id collection, NSFastEnumerationState *);
void LEGACYCollectionSetValueForKey(id<LEGACYCollectionPrivate> collection, NSString *key, id _Nullable value);
FOUNDATION_EXTERN NSString *LEGACYDescriptionWithMaxDepth(NSString *name, id<LEGACYCollection> collection, NSUInteger depth);
FOUNDATION_EXTERN void LEGACYAssignToCollection(id<LEGACYCollection> collection, id value);
FOUNDATION_EXTERN void LEGACYSetSwiftBridgeCallback(id _Nullable (*_Nonnull)(id));

FOUNDATION_EXTERN
LEGACYNotificationToken *LEGACYAddNotificationBlock(id collection, id block,
                                              NSArray<NSString *> *_Nullable keyPaths,
                                              dispatch_queue_t _Nullable queue);

typedef LEGACY_CLOSED_ENUM(int32_t, LEGACYCollectionType) {
    LEGACYCollectionTypeArray = 0,
    LEGACYCollectionTypeSet = 1,
    LEGACYCollectionTypeDictionary = 2
};

LEGACY_HEADER_AUDIT_END(nullability, sendability)
