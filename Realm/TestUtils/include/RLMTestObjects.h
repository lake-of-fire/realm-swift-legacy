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

#import <Realm/Realm.h>

#define LEGACY_GENERIC_ARRAY(CLASS) LEGACYArray<CLASS *><CLASS>
#define LEGACY_GENERIC_SET(CLASS) LEGACYSet<CLASS *><CLASS>

#pragma mark - Abstract Objects
#pragma mark -

#pragma mark SingleTypeObjects

@interface StringObject : LEGACYObject

@property NSString *stringCol;

@property(readonly) NSString *firstLetter;

@end

@interface IntObject : LEGACYObject

@property int intCol;

@end

@interface AllIntSizesObject : LEGACYObject
// int8_t not supported due to being ambiguous with BOOL

@property int16_t int16;
@property int32_t int32;
@property int64_t int64;

@end

@interface FloatObject : LEGACYObject

@property float floatCol;

@end

@interface DoubleObject : LEGACYObject

@property double doubleCol;

@end

@interface BoolObject : LEGACYObject

@property BOOL boolCol;

@end

@interface DateObject : LEGACYObject

@property NSDate *dateCol;

@end

@interface BinaryObject : LEGACYObject

@property NSData *binaryCol;

@end

@interface DecimalObject : LEGACYObject
@property LEGACYDecimal128 *decimalCol;
@end

@interface UTF8Object : LEGACYObject
@property NSString *柱колоéнǢкƱаم;
@end

@interface IndexedStringObject : LEGACYObject
@property NSString *stringCol;
@end

LEGACY_COLLECTION_TYPE(StringObject)
LEGACY_COLLECTION_TYPE(IntObject)

@interface LinkStringObject : LEGACYObject
@property StringObject *objectCol;
@end

@interface LinkIndexedStringObject : LEGACYObject
@property IndexedStringObject *objectCol;
@end

@interface RequiredPropertiesObject : LEGACYObject
@property NSString *stringCol;
@property NSData *binaryCol;
@property NSDate *dateCol;
@end

@interface IgnoredURLObject : LEGACYObject
@property NSString *name;
@property NSURL *url;
@end

@interface EmbeddedIntObject : LEGACYEmbeddedObject
@property int intCol;
@end
LEGACY_COLLECTION_TYPE(EmbeddedIntObject)

@interface EmbeddedIntParentObject : LEGACYObject
@property int pk;
@property EmbeddedIntObject *object;
@property LEGACYArray<EmbeddedIntObject> *array;
@end

@interface UuidObject: LEGACYObject
@property NSUUID *uuidCol;
@end

@interface MixedObject: LEGACYObject
@property id<LEGACYValue> anyCol;
@property LEGACYArray<LEGACYValue> *anyArray;
@end

#pragma mark AllTypesObject

@interface AllTypesObject : LEGACYObject
@property BOOL          boolCol;
@property int           intCol;
@property float         floatCol;
@property double        doubleCol;
@property NSString     *stringCol;
@property NSData       *binaryCol;
@property NSDate       *dateCol;
@property bool          cBoolCol;
@property int64_t       longCol;
@property LEGACYDecimal128 *decimalCol;
@property LEGACYObjectId  *objectIdCol;
@property NSUUID       *uuidCol;
@property StringObject *objectCol;
@property MixedObject  *mixedObjectCol;
@property (readonly) LEGACYLinkingObjects *linkingObjectsCol;
@property id<LEGACYValue> anyCol;

+ (NSDictionary *)values:(int)i stringObject:(StringObject *)so;
+ (NSDictionary *)values:(int)i
            stringObject:(StringObject *)so
             mixedObject:(MixedObject *)mo;
@end

LEGACY_COLLECTION_TYPE(AllTypesObject)

@interface LinkToAllTypesObject : LEGACYObject
@property AllTypesObject *allTypesCol;
@end

@interface ArrayOfAllTypesObject : LEGACYObject
@property LEGACY_GENERIC_ARRAY(AllTypesObject) *array;
@end

@interface SetOfAllTypesObject : LEGACYObject
@property LEGACY_GENERIC_SET(AllTypesObject) *set;
@end

@interface DictionaryOfAllTypesObject : LEGACYObject
@property LEGACYDictionary<NSString *, AllTypesObject*><LEGACYString, AllTypesObject> *dictionary;
@end

@interface AllOptionalTypes : LEGACYObject
@property NSNumber<LEGACYInt> *intObj;
@property NSNumber<LEGACYFloat> *floatObj;
@property NSNumber<LEGACYDouble> *doubleObj;
@property NSNumber<LEGACYBool> *boolObj;
@property NSString *string;
@property NSData *data;
@property NSDate *date;
@property LEGACYDecimal128 *decimal;
@property LEGACYObjectId *objectId;
@property NSUUID *uuidCol;
@end

@interface AllOptionalTypesPK : LEGACYObject
@property int pk;

@property NSNumber<LEGACYInt> *intObj;
@property NSNumber<LEGACYFloat> *floatObj;
@property NSNumber<LEGACYDouble> *doubleObj;
@property NSNumber<LEGACYBool> *boolObj;
@property NSString *string;
@property NSData *data;
@property NSDate *date;
@property LEGACYDecimal128 *decimal;
@property LEGACYObjectId *objectId;
@property NSUUID *uuidCol;
@end

@interface AllPrimitiveArrays : LEGACYObject
@property LEGACYArray<LEGACYInt> *intObj;
@property LEGACYArray<LEGACYFloat> *floatObj;
@property LEGACYArray<LEGACYDouble> *doubleObj;
@property LEGACYArray<LEGACYBool> *boolObj;
@property LEGACYArray<LEGACYString> *stringObj;
@property LEGACYArray<LEGACYDate> *dateObj;
@property LEGACYArray<LEGACYData> *dataObj;
@property LEGACYArray<LEGACYDecimal128> *decimalObj;
@property LEGACYArray<LEGACYObjectId> *objectIdObj;
@property LEGACYArray<LEGACYUUID> *uuidObj;
@property LEGACYArray<LEGACYValue> *anyBoolObj;
@property LEGACYArray<LEGACYValue> *anyIntObj;
@property LEGACYArray<LEGACYValue> *anyFloatObj;
@property LEGACYArray<LEGACYValue> *anyDoubleObj;
@property LEGACYArray<LEGACYValue> *anyStringObj;
@property LEGACYArray<LEGACYValue> *anyDataObj;
@property LEGACYArray<LEGACYValue> *anyDateObj;
@property LEGACYArray<LEGACYValue> *anyDecimalObj;
@property LEGACYArray<LEGACYValue> *anyObjectIdObj;
@property LEGACYArray<LEGACYValue> *anyUUIDObj;
@end

@interface AllOptionalPrimitiveArrays : LEGACYObject
@property LEGACYArray<LEGACYInt> *intObj;
@property LEGACYArray<LEGACYFloat> *floatObj;
@property LEGACYArray<LEGACYDouble> *doubleObj;
@property LEGACYArray<LEGACYBool> *boolObj;
@property LEGACYArray<LEGACYString> *stringObj;
@property LEGACYArray<LEGACYDate> *dateObj;
@property LEGACYArray<LEGACYData> *dataObj;
@property LEGACYArray<LEGACYDecimal128> *decimalObj;
@property LEGACYArray<LEGACYObjectId> *objectIdObj;
@property LEGACYArray<LEGACYUUID> *uuidObj;
@end

@interface AllPrimitiveSets : LEGACYObject
@property LEGACYSet<LEGACYInt> *intObj;
@property LEGACYSet<LEGACYInt> *intObj2;
@property LEGACYSet<LEGACYFloat> *floatObj;
@property LEGACYSet<LEGACYFloat> *floatObj2;
@property LEGACYSet<LEGACYDouble> *doubleObj;
@property LEGACYSet<LEGACYDouble> *doubleObj2;
@property LEGACYSet<LEGACYBool> *boolObj;
@property LEGACYSet<LEGACYBool> *boolObj2;
@property LEGACYSet<LEGACYString> *stringObj;
@property LEGACYSet<LEGACYString> *stringObj2;
@property LEGACYSet<LEGACYDate> *dateObj;
@property LEGACYSet<LEGACYDate> *dateObj2;
@property LEGACYSet<LEGACYData> *dataObj;
@property LEGACYSet<LEGACYData> *dataObj2;
@property LEGACYSet<LEGACYDecimal128> *decimalObj;
@property LEGACYSet<LEGACYDecimal128> *decimalObj2;
@property LEGACYSet<LEGACYObjectId> *objectIdObj;
@property LEGACYSet<LEGACYObjectId> *objectIdObj2;
@property LEGACYSet<LEGACYUUID> *uuidObj;
@property LEGACYSet<LEGACYUUID> *uuidObj2;

@property LEGACYSet<LEGACYValue> *anyBoolObj;
@property LEGACYSet<LEGACYValue> *anyBoolObj2;
@property LEGACYSet<LEGACYValue> *anyIntObj;
@property LEGACYSet<LEGACYValue> *anyIntObj2;
@property LEGACYSet<LEGACYValue> *anyFloatObj;
@property LEGACYSet<LEGACYValue> *anyFloatObj2;
@property LEGACYSet<LEGACYValue> *anyDoubleObj;
@property LEGACYSet<LEGACYValue> *anyDoubleObj2;
@property LEGACYSet<LEGACYValue> *anyStringObj;
@property LEGACYSet<LEGACYValue> *anyStringObj2;
@property LEGACYSet<LEGACYValue> *anyDataObj;
@property LEGACYSet<LEGACYValue> *anyDataObj2;
@property LEGACYSet<LEGACYValue> *anyDateObj;
@property LEGACYSet<LEGACYValue> *anyDateObj2;
@property LEGACYSet<LEGACYValue> *anyDecimalObj;
@property LEGACYSet<LEGACYValue> *anyDecimalObj2;
@property LEGACYSet<LEGACYValue> *anyObjectIdObj;
@property LEGACYSet<LEGACYValue> *anyObjectIdObj2;
@property LEGACYSet<LEGACYValue> *anyUUIDObj;
@property LEGACYSet<LEGACYValue> *anyUUIDObj2;

@end

@interface AllOptionalPrimitiveSets : LEGACYObject
@property LEGACYSet<LEGACYInt> *intObj;
@property LEGACYSet<LEGACYInt> *intObj2;
@property LEGACYSet<LEGACYFloat> *floatObj;
@property LEGACYSet<LEGACYFloat> *floatObj2;
@property LEGACYSet<LEGACYDouble> *doubleObj;
@property LEGACYSet<LEGACYDouble> *doubleObj2;
@property LEGACYSet<LEGACYBool> *boolObj;
@property LEGACYSet<LEGACYBool> *boolObj2;
@property LEGACYSet<LEGACYString> *stringObj;
@property LEGACYSet<LEGACYString> *stringObj2;
@property LEGACYSet<LEGACYDate> *dateObj;
@property LEGACYSet<LEGACYDate> *dateObj2;
@property LEGACYSet<LEGACYData> *dataObj;
@property LEGACYSet<LEGACYData> *dataObj2;
@property LEGACYSet<LEGACYDecimal128> *decimalObj;
@property LEGACYSet<LEGACYDecimal128> *decimalObj2;
@property LEGACYSet<LEGACYObjectId> *objectIdObj;
@property LEGACYSet<LEGACYObjectId> *objectIdObj2;
@property LEGACYSet<LEGACYUUID> *uuidObj;
@property LEGACYSet<LEGACYUUID> *uuidObj2;
@end

@interface AllPrimitiveLEGACYValues : LEGACYObject
@property id<LEGACYValue> nullVal;
@property id<LEGACYValue> intVal;
@property id<LEGACYValue> floatVal;
@property id<LEGACYValue> doubleVal;
@property id<LEGACYValue> boolVal;
@property id<LEGACYValue> stringVal;
@property id<LEGACYValue> dateVal;
@property id<LEGACYValue> dataVal;
@property id<LEGACYValue> decimalVal;
@property id<LEGACYValue> objectIdVal;
@property id<LEGACYValue> uuidVal;
@end

@interface AllDictionariesObject : LEGACYObject
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYInt> *intDict;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYFloat> *floatDict;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYDouble> *doubleDict;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYBool> *boolDict;
@property LEGACYDictionary<NSString *, NSString *><LEGACYString, LEGACYString> *stringDict;
@property LEGACYDictionary<NSString *, NSDate *><LEGACYString, LEGACYDate> *dateDict;
@property LEGACYDictionary<NSString *, NSData *><LEGACYString, LEGACYData> *dataDict;
@property LEGACYDictionary<NSString *, LEGACYDecimal128 *><LEGACYString, LEGACYDecimal128> *decimalDict;
@property LEGACYDictionary<NSString *, LEGACYObjectId *><LEGACYString, LEGACYObjectId> *objectIdDict;
@property LEGACYDictionary<NSString *, NSUUID *><LEGACYString, LEGACYUUID> *uuidDict;
@property LEGACYDictionary<NSString *, StringObject *><LEGACYString, StringObject> *stringObjDict;
@end

@interface AllPrimitiveDictionaries : LEGACYObject
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYInt> *intObj;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYFloat> *floatObj;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYDouble> *doubleObj;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYBool> *boolObj;
@property LEGACYDictionary<NSString *, NSString *><LEGACYString, LEGACYString> *stringObj;
@property LEGACYDictionary<NSString *, NSDate *><LEGACYString, LEGACYDate> *dateObj;
@property LEGACYDictionary<NSString *, NSData *><LEGACYString, LEGACYData> *dataObj;
@property LEGACYDictionary<NSString *, LEGACYDecimal128 *><LEGACYString, LEGACYDecimal128> *decimalObj;
@property LEGACYDictionary<NSString *, LEGACYObjectId *><LEGACYString, LEGACYObjectId> *objectIdObj;
@property LEGACYDictionary<NSString *, NSUUID *><LEGACYString, LEGACYUUID> *uuidObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyBoolObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyIntObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyFloatObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyDoubleObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyStringObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyDataObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyDateObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyDecimalObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyObjectIdObj;
@property LEGACYDictionary<NSString *, NSObject *><LEGACYString, LEGACYValue> *anyUUIDObj;
@end

@interface AllOptionalPrimitiveDictionaries : LEGACYObject
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYInt> *intObj;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYFloat> *floatObj;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYDouble> *doubleObj;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYBool> *boolObj;
@property LEGACYDictionary<NSString *, NSString *><LEGACYString, LEGACYString> *stringObj;
@property LEGACYDictionary<NSString *, NSDate *><LEGACYString, LEGACYDate> *dateObj;
@property LEGACYDictionary<NSString *, NSData *><LEGACYString, LEGACYData> *dataObj;
@property LEGACYDictionary<NSString *, LEGACYDecimal128 *><LEGACYString, LEGACYDecimal128> *decimalObj;
@property LEGACYDictionary<NSString *, LEGACYObjectId *><LEGACYString, LEGACYObjectId> *objectIdObj;
@property LEGACYDictionary<NSString *, NSUUID *><LEGACYString, LEGACYUUID> *uuidObj;
@end

#pragma mark - Real Life Objects
#pragma mark -

#pragma mark EmployeeObject

@interface EmployeeObject : LEGACYObject

@property NSString *name;
@property int age;
@property BOOL hired;

@end

LEGACY_COLLECTION_TYPE(EmployeeObject)

#pragma mark CompanyObject

@interface CompanyObject : LEGACYObject

@property NSString *name;
@property LEGACY_GENERIC_ARRAY(EmployeeObject) *employees;
@property LEGACY_GENERIC_SET(EmployeeObject) *employeeSet;
@property LEGACYDictionary<NSString *, EmployeeObject *><LEGACYString, EmployeeObject> *employeeDict;

@end

#pragma mark LinkToCompanyObject

@interface LinkToCompanyObject : LEGACYObject

@property CompanyObject *company;

@end

#pragma mark DogObject

@interface DogObject : LEGACYObject
@property NSString *dogName;
@property int age;
@property (readonly) LEGACYLinkingObjects *owners;
@end

LEGACY_COLLECTION_TYPE(DogObject)

@interface DogArrayObject : LEGACYObject
@property LEGACY_GENERIC_ARRAY(DogObject) *dogs;
@end

@interface DogSetObject : LEGACYObject
@property LEGACY_GENERIC_SET(DogObject) *dogs;
@end

@interface DogDictionaryObject : LEGACYObject
@property LEGACYDictionary<NSString *, DogObject *><LEGACYString, DogObject> *dogs;
@end

#pragma mark OwnerObject

@interface OwnerObject : LEGACYObject

@property NSString *name;
@property DogObject *dog;

@end

#pragma mark - Specific Use Objects
#pragma mark -

#pragma mark CustomAccessorsObject

@interface CustomAccessorsObject : LEGACYObject

@property (getter = getThatName) NSString *name;
@property (setter = setTheInt:)  int age;

@end

#pragma mark BaseClassStringObject

@interface BaseClassStringObject : LEGACYObject

@property int intCol;

@end

@interface BaseClassStringObject ()

@property NSString *stringCol;

@end

#pragma mark CircleObject

@interface CircleObject : LEGACYObject

@property NSString *data;
@property CircleObject *next;

@end

LEGACY_COLLECTION_TYPE(CircleObject);

#pragma mark CircleArrayObject

@interface CircleArrayObject : LEGACYObject
@property LEGACY_GENERIC_ARRAY(CircleObject) *circles;
@end

#pragma mark CircleSetObject

@interface CircleSetObject : LEGACYObject
@property LEGACY_GENERIC_SET(CircleObject) *circles;
@end

#pragma mark CircleDictionaryObject

@interface CircleDictionaryObject : LEGACYObject
@property LEGACYDictionary<NSString *, CircleObject *><LEGACYString, CircleObject> *circles;
@end

#pragma mark ArrayPropertyObject

@interface ArrayPropertyObject : LEGACYObject

@property NSString *name;
@property LEGACY_GENERIC_ARRAY(StringObject) *array;
@property LEGACY_GENERIC_ARRAY(IntObject) *intArray;

@end

#pragma mark SetPropertyObject

@interface SetPropertyObject : LEGACYObject

@property NSString *name;
@property LEGACY_GENERIC_SET(StringObject) *set;
@property LEGACY_GENERIC_SET(IntObject) *intSet;

@end

#pragma mark DictionaryPropertyObject

@interface DictionaryPropertyObject : LEGACYObject
@property LEGACYDictionary<NSString *, StringObject *><LEGACYString, StringObject> *stringDictionary;
@property LEGACYDictionary<NSString *, NSNumber *><LEGACYString, LEGACYInt> *intDictionary;
@property LEGACYDictionary<NSString *, NSString *><LEGACYString, LEGACYString> *primitiveStringDictionary;
@property LEGACYDictionary<NSString *, EmbeddedIntObject *><LEGACYString, EmbeddedIntObject> *embeddedDictionary;
@property LEGACYDictionary<NSString *, IntObject *><LEGACYString, IntObject> *intObjDictionary;
@end

#pragma mark DynamicObject

@interface DynamicTestObject : LEGACYObject

@property NSString *stringCol;
@property int intCol;

@end

#pragma mark AggregateObject

@interface AggregateObject : LEGACYObject

@property int     intCol;
@property float   floatCol;
@property double  doubleCol;
@property BOOL    boolCol;
@property NSDate *dateCol;
@property id<LEGACYValue> anyCol;

@end

LEGACY_COLLECTION_TYPE(AggregateObject)
@interface AggregateArrayObject : LEGACYObject
@property LEGACYArray<AggregateObject *><AggregateObject> *array;
@end

@interface AggregateSetObject : LEGACYObject
@property LEGACYSet<AggregateObject *><AggregateObject> *set;
@end

@interface AggregateDictionaryObject : LEGACYObject
@property LEGACYDictionary<NSString *, AggregateObject *><LEGACYString, AggregateObject> *dictionary;
@end

#pragma mark PrimaryStringObject

@interface PrimaryStringObject : LEGACYObject
@property NSString *stringCol;
@property int intCol;
@end

@interface PrimaryNullableStringObject : LEGACYObject
@property NSString *stringCol;
@property int intCol;
@end

@interface PrimaryIntObject : LEGACYObject
@property int intCol;
@end
LEGACY_COLLECTION_TYPE(PrimaryIntObject);

@interface PrimaryInt64Object : LEGACYObject
@property int64_t int64Col;
@end

@interface PrimaryNullableIntObject : LEGACYObject
@property NSNumber<LEGACYInt> *optIntCol;
@property int value;
@end

@interface ReadOnlyPropertyObject : LEGACYObject
@property (readonly) NSNumber *readOnlyUnsupportedProperty;
@property (readonly) int readOnlySupportedProperty;
@property (readonly) int readOnlyPropertyMadeReadWriteInClassExtension;
@end

#pragma mark IntegerArrayPropertyObject

@interface IntegerArrayPropertyObject : LEGACYObject

@property NSInteger number;
@property LEGACY_GENERIC_ARRAY(IntObject) *array;

@end

#pragma mark IntegerSetPropertyObject

@interface IntegerSetPropertyObject : LEGACYObject

@property NSInteger number;
@property LEGACY_GENERIC_SET(IntObject) *set;

@end

#pragma mark IntegerDictionaryPropertyObject

@interface IntegerDictionaryPropertyObject : LEGACYObject

@property NSInteger number;
@property LEGACYDictionary<NSString *, IntObject *><LEGACYString, IntObject> *dictionary;

@end

@interface NumberObject : LEGACYObject
@property NSNumber<LEGACYInt> *intObj;
@property NSNumber<LEGACYFloat> *floatObj;
@property NSNumber<LEGACYDouble> *doubleObj;
@property NSNumber<LEGACYBool> *boolObj;
@end

@interface NumberDefaultsObject : NumberObject
@end

@interface RequiredNumberObject : LEGACYObject
@property NSNumber<LEGACYInt> *intObj;
@property NSNumber<LEGACYFloat> *floatObj;
@property NSNumber<LEGACYDouble> *doubleObj;
@property NSNumber<LEGACYBool> *boolObj;
@end

#pragma mark CustomInitializerObject

@interface CustomInitializerObject : LEGACYObject
@property NSString *stringCol;
@end

#pragma mark AbstractObject

@interface AbstractObject : LEGACYObject
@end

#pragma mark PersonObject

@class PersonObject;
LEGACY_COLLECTION_TYPE(PersonObject);

@interface PersonObject : LEGACYObject
@property NSString *name;
@property NSInteger age;
@property LEGACYArray<PersonObject> *children;
@property (readonly) LEGACYLinkingObjects *parents;
@end

@interface PrimaryEmployeeObject : EmployeeObject
@end
LEGACY_COLLECTION_TYPE(PrimaryEmployeeObject);

@interface LinkToPrimaryEmployeeObject : LEGACYObject
@property PrimaryEmployeeObject *wrapped;
@end

@interface PrimaryCompanyObject : LEGACYObject
@property NSString *name;
@property LEGACY_GENERIC_ARRAY(PrimaryEmployeeObject) *employees;
@property LEGACY_GENERIC_SET(PrimaryEmployeeObject) *employeeSet;
@property LEGACYDictionary<NSString *, PrimaryEmployeeObject *><LEGACYString, PrimaryEmployeeObject> *employeeDict;
@property PrimaryEmployeeObject *intern;
@property LinkToPrimaryEmployeeObject *wrappedIntern;
@end
LEGACY_COLLECTION_TYPE(PrimaryCompanyObject);

@interface ArrayOfPrimaryCompanies : LEGACYObject
@property LEGACY_GENERIC_ARRAY(PrimaryCompanyObject) *companies;
@end

@interface SetOfPrimaryCompanies : LEGACYObject
@property LEGACY_GENERIC_SET(PrimaryCompanyObject) *companies;
@end

#pragma mark ComputedPropertyNotExplicitlyIgnoredObject

@interface ComputedPropertyNotExplicitlyIgnoredObject : LEGACYObject
@property NSString *_URLBacking;
@property NSURL *URL;
@end

@interface RenamedProperties : LEGACYObject
@property (nonatomic) int intCol;
@property NSString *stringCol;
@end

@interface RenamedProperties1 : LEGACYObject
@property (nonatomic) int propA;
@property (nonatomic) NSString *propB;
@property (readonly, nonatomic) LEGACYLinkingObjects *linking1;
@property (readonly, nonatomic) LEGACYLinkingObjects *linking2;
@end

@interface RenamedProperties2 : LEGACYObject
@property (nonatomic) int propC;
@property (nonatomic) NSString *propD;
@property (readonly, nonatomic) LEGACYLinkingObjects *linking1;
@property (readonly, nonatomic) LEGACYLinkingObjects *linking2;
@end

LEGACY_COLLECTION_TYPE(RenamedProperties1)
LEGACY_COLLECTION_TYPE(RenamedProperties2)
LEGACY_COLLECTION_TYPE(RenamedProperties)

@interface LinkToRenamedProperties : LEGACYObject
@property (nonatomic) RenamedProperties *link;
@property (nonatomic) LEGACY_GENERIC_ARRAY(RenamedProperties) *array;
@property (nonatomic) LEGACY_GENERIC_SET(RenamedProperties) *set;
@property (nonatomic) LEGACYDictionary<NSString *, RenamedProperties *><LEGACYString, RenamedProperties> *dictionary;
@end

@interface LinkToRenamedProperties1 : LEGACYObject
@property (nonatomic) RenamedProperties1 *linkA;
@property (nonatomic) RenamedProperties2 *linkB;
@property (nonatomic) LEGACY_GENERIC_ARRAY(RenamedProperties1) *array;
@property (nonatomic) LEGACY_GENERIC_SET(RenamedProperties1) *set;
@property (nonatomic) LEGACYDictionary<NSString *, RenamedProperties1 *><LEGACYString, RenamedProperties1> *dictionary;
@end

@interface LinkToRenamedProperties2 : LEGACYObject
@property (nonatomic) RenamedProperties2 *linkC;
@property (nonatomic) RenamedProperties1 *linkD;
@property (nonatomic) LEGACY_GENERIC_ARRAY(RenamedProperties2) *array;
@property (nonatomic) LEGACY_GENERIC_SET(RenamedProperties2) *set;
@property (nonatomic) LEGACYDictionary<NSString *, RenamedProperties2 *><LEGACYString, RenamedProperties2> *dictionary;
@end

@interface RenamedPrimaryKey : LEGACYObject
@property (nonatomic) int pk;
@property (nonatomic) int value;
@end

#pragma mark FakeObject

@interface FakeObject : LEGACYObject
@end

@interface FakeEmbeddedObject : LEGACYEmbeddedObject
@end
