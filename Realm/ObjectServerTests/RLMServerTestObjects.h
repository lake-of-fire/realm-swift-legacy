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

#import "LEGACYTestObjects.h"

@interface Dog : LEGACYObject

@property LEGACYObjectId *_id;
@property NSString *breed;
@property NSString *name;
@property NSString *partition;
- (instancetype)initWithPrimaryKey:(LEGACYObjectId *)primaryKey breed:(NSString *)breed name:(NSString *)name;
@end

@interface Person : LEGACYObject
@property LEGACYObjectId *_id;
@property NSInteger age;
@property NSString *firstName;
@property NSString *lastName;
@property NSString *partition;

- (instancetype)initWithPrimaryKey:(LEGACYObjectId *)primaryKey age:(NSInteger)age firstName:(NSString *)firstName lastName:(NSString *)lastName;
+ (instancetype)john;
+ (instancetype)paul;
+ (instancetype)ringo;
+ (instancetype)george;
+ (instancetype)stuart;
@end

@interface HugeSyncObject : LEGACYObject
@property LEGACYObjectId *_id;
@property NSData *dataProp;
+ (instancetype)hugeSyncObject;
@end

@interface UUIDPrimaryKeyObject : LEGACYObject
@property NSUUID *_id;
@property NSString *strCol;
@property NSInteger intCol;
- (instancetype)initWithPrimaryKey:(NSUUID *)primaryKey strCol:(NSString *)strCol intCol:(NSInteger)intCol;
@end

@interface StringPrimaryKeyObject : LEGACYObject
@property NSString *_id;
@property NSString *strCol;
@property NSInteger intCol;
- (instancetype)initWithPrimaryKey:(NSString *)primaryKey strCol:(NSString *)strCol intCol:(NSInteger)intCol;
@end

@interface IntPrimaryKeyObject : LEGACYObject
@property NSInteger _id;
@property NSString *strCol;
@property NSInteger intCol;
- (instancetype)initWithPrimaryKey:(NSInteger)primaryKey strCol:(NSString *)strCol intCol:(NSInteger)intCol;
@end

@interface AllTypesSyncObject : LEGACYObject
@property LEGACYObjectId *_id;
@property BOOL boolCol;
@property bool cBoolCol;
@property int intCol;
@property double doubleCol;
@property NSString *stringCol;
@property NSData *binaryCol;
@property NSDate *dateCol;
@property int64_t longCol;
@property LEGACYDecimal128 *decimalCol;
@property NSUUID *uuidCol;
@property id<LEGACYValue> anyCol;
@property Person *objectCol;
+ (NSDictionary *)values:(int)i;
@end

LEGACY_COLLECTION_TYPE(Person);
@interface LEGACYArraySyncObject : LEGACYObject
@property LEGACYObjectId *_id;
@property LEGACYArray<LEGACYInt> *intArray;
@property LEGACYArray<LEGACYBool> *boolArray;
@property LEGACYArray<LEGACYString> *stringArray;
@property LEGACYArray<LEGACYData> *dataArray;
@property LEGACYArray<LEGACYDouble> *doubleArray;
@property LEGACYArray<LEGACYObjectId> *objectIdArray;
@property LEGACYArray<LEGACYDecimal128> *decimalArray;
@property LEGACYArray<LEGACYUUID> *uuidArray;
@property LEGACYArray<LEGACYValue> *anyArray;
@property LEGACY_GENERIC_ARRAY(Person) *objectArray;
@end

@interface LEGACYSetSyncObject : LEGACYObject
@property LEGACYObjectId *_id;
@property LEGACYSet<LEGACYInt> *intSet;
@property LEGACYSet<LEGACYBool> *boolSet;
@property LEGACYSet<LEGACYString> *stringSet;
@property LEGACYSet<LEGACYData> *dataSet;
@property LEGACYSet<LEGACYDouble> *doubleSet;
@property LEGACYSet<LEGACYObjectId> *objectIdSet;
@property LEGACYSet<LEGACYDecimal128> *decimalSet;
@property LEGACYSet<LEGACYUUID> *uuidSet;
@property LEGACYSet<LEGACYValue> *anySet;
@property LEGACY_GENERIC_SET(Person) *objectSet;

@property LEGACYSet<LEGACYInt> *otherIntSet;
@property LEGACYSet<LEGACYBool> *otherBoolSet;
@property LEGACYSet<LEGACYString> *otherStringSet;
@property LEGACYSet<LEGACYData> *otherDataSet;
@property LEGACYSet<LEGACYDouble> *otherDoubleSet;
@property LEGACYSet<LEGACYObjectId> *otherObjectIdSet;
@property LEGACYSet<LEGACYDecimal128> *otherDecimalSet;
@property LEGACYSet<LEGACYUUID> *otherUuidSet;
@property LEGACYSet<LEGACYValue> *otherAnySet;
@property LEGACY_GENERIC_SET(Person) *otherObjectSet;
@end

@interface LEGACYDictionarySyncObject : LEGACYObject
@property LEGACYObjectId *_id;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYInt> *intDictionary;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYBool> *boolDictionary;
@property LEGACYDictionary<NSString *, NSString *><LEGACYString, LEGACYString> *stringDictionary;
@property LEGACYDictionary<NSString *, NSData *><LEGACYString, LEGACYData> *dataDictionary;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYDouble> *doubleDictionary;
@property LEGACYDictionary<NSString *, LEGACYObjectId *><LEGACYString, LEGACYObjectId> *objectIdDictionary;
@property LEGACYDictionary<NSString *, LEGACYDecimal128 *><LEGACYString, LEGACYDecimal128> *decimalDictionary;
@property LEGACYDictionary<NSString *, NSUUID *><LEGACYString, LEGACYUUID> *uuidDictionary;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyDictionary;
@property LEGACYDictionary<NSString *, Person *><LEGACYString, Person> *objectDictionary;

@end
