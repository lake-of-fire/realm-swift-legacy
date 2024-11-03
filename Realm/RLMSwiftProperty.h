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

#import <Foundation/Foundation.h>
#import <stdint.h>

@class LEGACYObjectBase, LEGACYArray, LEGACYSet;

#ifdef __cplusplus
extern "C" {
#endif

LEGACY_HEADER_AUDIT_BEGIN(nullability)

#define REALM_FOR_EACH_SWIFT_PRIMITIVE_TYPE(macro) \
    macro(bool, Bool, bool) \
    macro(double, Double, double) \
    macro(float, Float, float) \
    macro(int64_t, Int64, int)

#define REALM_FOR_EACH_SWIFT_OBJECT_TYPE(macro) \
    macro(NSString, String, string) \
    macro(NSDate, Date, date) \
    macro(NSData, Data, data) \
    macro(NSUUID, UUID, uuid) \
    macro(LEGACYDecimal128, Decimal128, decimal128) \
    macro(LEGACYObjectId, ObjectId, objectId)

#define REALM_SWIFT_PROPERTY_ACCESSOR(objc, swift, rlmtype) \
    objc LEGACYGetSwiftProperty##swift(LEGACYObjectBase *, uint16_t); \
    objc LEGACYGetSwiftProperty##swift##Optional(LEGACYObjectBase *, uint16_t, bool *); \
    void LEGACYSetSwiftProperty##swift(LEGACYObjectBase *, uint16_t, objc);
REALM_FOR_EACH_SWIFT_PRIMITIVE_TYPE(REALM_SWIFT_PROPERTY_ACCESSOR)
#undef REALM_SWIFT_PROPERTY_ACCESSOR

#define REALM_SWIFT_PROPERTY_ACCESSOR(objc, swift, rlmtype) \
    objc *_Nullable LEGACYGetSwiftProperty##swift(LEGACYObjectBase *, uint16_t); \
    void LEGACYSetSwiftProperty##swift(LEGACYObjectBase *, uint16_t, objc *_Nullable);
REALM_FOR_EACH_SWIFT_OBJECT_TYPE(REALM_SWIFT_PROPERTY_ACCESSOR)
#undef REALM_SWIFT_PROPERTY_ACCESSOR

id<LEGACYValue> _Nullable LEGACYGetSwiftPropertyAny(LEGACYObjectBase *, uint16_t);
void LEGACYSetSwiftPropertyAny(LEGACYObjectBase *, uint16_t, id<LEGACYValue>);
LEGACYObjectBase *_Nullable LEGACYGetSwiftPropertyObject(LEGACYObjectBase *, uint16_t);
void LEGACYSetSwiftPropertyNil(LEGACYObjectBase *, uint16_t);
void LEGACYSetSwiftPropertyObject(LEGACYObjectBase *, uint16_t, LEGACYObjectBase *_Nullable);

LEGACYArray *_Nonnull LEGACYGetSwiftPropertyArray(LEGACYObjectBase *obj, uint16_t);
LEGACYSet *_Nonnull LEGACYGetSwiftPropertySet(LEGACYObjectBase *obj, uint16_t);
LEGACYDictionary *_Nonnull LEGACYGetSwiftPropertyMap(LEGACYObjectBase *obj, uint16_t);

LEGACY_HEADER_AUDIT_END(nullability)

#ifdef __cplusplus
} // extern "C"
#endif
