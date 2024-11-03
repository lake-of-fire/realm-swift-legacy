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

#import <Realm/LEGACYObjectId.h>
#import <Realm/LEGACYDecimal128.h>

#pragma mark LEGACYBSONType

/**
 Allowed BSON types.
 */
typedef NS_ENUM(NSUInteger, LEGACYBSONType) {
    /// BSON Null type
    LEGACYBSONTypeNull,
    /// BSON Int32 type
    LEGACYBSONTypeInt32,
    /// BSON Int64 type
    LEGACYBSONTypeInt64,
    /// BSON Bool type
    LEGACYBSONTypeBool,
    /// BSON Double type
    LEGACYBSONTypeDouble,
    /// BSON String type
    LEGACYBSONTypeString,
    /// BSON Binary type
    LEGACYBSONTypeBinary,
    /// BSON Timestamp type
    LEGACYBSONTypeTimestamp,
    /// BSON Datetime type
    LEGACYBSONTypeDatetime,
    /// BSON ObjectId type
    LEGACYBSONTypeObjectId,
    /// BSON Decimal128 type
    LEGACYBSONTypeDecimal128,
    /// BSON RegularExpression type
    LEGACYBSONTypeRegularExpression,
    /// BSON MaxKey type
    LEGACYBSONTypeMaxKey,
    /// BSON MinKey type
    LEGACYBSONTypeMinKey,
    /// BSON Document type
    LEGACYBSONTypeDocument,
    /// BSON Array type
    LEGACYBSONTypeArray,
    /// BSON UUID type
    LEGACYBSONTypeUUID
};

#pragma mark LEGACYBSON

/**
 Protocol representing a BSON value. BSON is a computer data interchange format.
 The name "BSON" is based on the term JSON and stands for "Binary JSON".
 
 The following types conform to LEGACYBSON:
 
 `NSNull`
 `NSNumber`
 `NSString`
 `NSData`
 `NSDateInterval`
 `NSDate`
 `LEGACYObjectId`
 `LEGACYDecimal128`
 `NSRegularExpression`
 `LEGACYMaxKey`
 `LEGACYMinKey`
 `NSDictionary`
 `NSArray`
 `NSUUID`
 
 @see LEGACYBSONType
 @see bsonspec.org
 */
@protocol LEGACYBSON

/**
 The BSON type for the conforming interface.
 */
@property (readonly) LEGACYBSONType bsonType NS_REFINED_FOR_SWIFT;

/**
 Whether or not this BSON is equal to another.

 @param other The BSON to compare to
 */
- (BOOL)isEqual:(_Nullable id)other;

@end

/// :nodoc:
@interface NSNull (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSNumber (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSString (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSData (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSDateInterval (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSDate (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface LEGACYObjectId (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface LEGACYDecimal128 (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSRegularExpression (LEGACYBSON)<LEGACYBSON>
@end

/// MaxKey will always be the greatest value when comparing to other BSON types
LEGACY_SWIFT_SENDABLE LEGACY_FINAL
@interface LEGACYMaxKey : NSObject
@end

/// MinKey will always be the smallest value when comparing to other BSON types
LEGACY_SWIFT_SENDABLE LEGACY_FINAL
@interface LEGACYMinKey : NSObject
@end

/// :nodoc:
@interface LEGACYMaxKey (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface LEGACYMinKey (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSDictionary (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSMutableArray (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSArray (LEGACYBSON)<LEGACYBSON>
@end

/// :nodoc:
@interface NSUUID (LEGACYBSON)<LEGACYBSON>
@end
