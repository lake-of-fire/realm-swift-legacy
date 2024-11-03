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

#import "LEGACYBSON_Private.hpp"

#import "LEGACYDecimal128_Private.hpp"
#import "LEGACYObjectId_Private.hpp"
#import "LEGACYUUID_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/util/bson/bson.hpp>

using namespace realm;
using namespace bson;

#pragma mark NSNull

@implementation NSNull (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeNull;
}

@end

#pragma mark LEGACYObjectId

@implementation LEGACYObjectId (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeObjectId;
}

@end

#pragma mark LEGACYDecimal128

@implementation LEGACYDecimal128 (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeDecimal128;
}

@end

#pragma mark NSString

@implementation NSString (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeString;
}

@end

#pragma mark NSNumber

@implementation NSNumber (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    char numberType = [self objCType][0];
    
    if (numberType == *@encode(bool) ||
        numberType == *@encode(char)) {
        return LEGACYBSONTypeBool;
    } else if (numberType == *@encode(int) ||
               numberType == *@encode(short) ||
               numberType == *@encode(unsigned short) ||
               numberType == *@encode(unsigned int)) {
        return LEGACYBSONTypeInt32;
    } else if (numberType == *@encode(long) ||
               numberType == *@encode(long long) ||
               numberType == *@encode(unsigned long) ||
               numberType == *@encode(unsigned long long)) {
        return LEGACYBSONTypeInt64;
    } else {
        return LEGACYBSONTypeDouble;
    }
}

@end

#pragma mark NSMutableArray

@implementation NSMutableArray (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeArray;
}

- (instancetype)initWithBsonArray:(BsonArray)bsonArray {

    if ((self = [self init])) {
        for (auto& entry : bsonArray) {
            [self addObject:LEGACYConvertBsonToRLMBSON(entry)];
        }

        return self;
    }

    return nil;
}

@end

@implementation NSArray (LEGACYBSON)

- (BsonArray)bsonArrayValue {
    BsonArray bsonArray;
    for (id value in self) {
        bsonArray.push_back(LEGACYConvertRLMBSONToBson(value));
    }
    return bsonArray;
}

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeArray;
}

@end

#pragma mark NSDictionary

@implementation NSMutableDictionary (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeDocument;
}

- (BsonDocument)bsonDocumentValue {
    BsonDocument bsonDocument;
    for (NSString *value in self) {
        bsonDocument[value.UTF8String] = LEGACYConvertRLMBSONToBson(self[value]);
    }
    return bsonDocument;
}

- (instancetype)initWithBsonDocument:(BsonDocument)bsonDocument {
    if ((self = [self init])) {
        for (auto it = bsonDocument.begin(); it != bsonDocument.end(); ++it) {
            const auto& entry = (*it);
            [self setObject:LEGACYConvertBsonToRLMBSON(entry.second) forKey:@(entry.first.data())];
        }

        return self;
    }

    return nil;
}

@end

@implementation NSDictionary (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeDocument;
}

- (BsonDocument)bsonDocumentValue {
    BsonDocument bsonDocument;
    for (NSString *value in self) {
        bsonDocument[value.UTF8String] = LEGACYConvertRLMBSONToBson(self[value]);
    }
    return bsonDocument;
}

@end

#pragma mark NSData

@implementation NSData (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeBinary;
}

- (instancetype)initWithBsonBinary:(std::vector<char>)bsonBinary {
    if ((self = [NSData dataWithBytes:bsonBinary.data() length:bsonBinary.size()])) {
        return self;
    }

    return nil;
}

@end

#pragma mark NSDate

@implementation NSDate (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeDatetime;
}

@end

#pragma mark NSUUID

@implementation NSUUID (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeUUID;
}

@end

#pragma mark NSRegularExpression

@implementation NSRegularExpression (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeRegularExpression;
}

- (RegularExpression)regularExpressionValue {
    using Option = RegularExpression::Option;
    std::string s;

    if ((_options & NSRegularExpressionCaseInsensitive) != 0) s += 'i';
    if ((_options & NSRegularExpressionUseUnixLineSeparators) != 0) s += 'm';
    if ((_options & NSRegularExpressionDotMatchesLineSeparators) != 0) s += 's';
    if ((_options & NSRegularExpressionUseUnicodeWordBoundaries) != 0) s += 'x';

    return RegularExpression(_pattern.UTF8String, s);
}

- (instancetype)initWithRegularExpression:(RegularExpression)regularExpression {
    if ((self = [self init])) {
        _pattern = @(regularExpression.pattern().data());
        switch (regularExpression.options()) {
            case realm::bson::RegularExpression::Option::None:
                _options = 0;
                break;
            case realm::bson::RegularExpression::Option::IgnoreCase:
                _options = NSRegularExpressionCaseInsensitive;
                break;
            case realm::bson::RegularExpression::Option::Multiline:
                _options = NSRegularExpressionUseUnixLineSeparators;
                break;
            case realm::bson::RegularExpression::Option::Dotall:
                _options = NSRegularExpressionDotMatchesLineSeparators;
                break;
            case realm::bson::RegularExpression::Option::Extended:
                _options = NSRegularExpressionUseUnicodeWordBoundaries;
                break;
        }
        return self;
    }

    return nil;
}

@end

#pragma mark LEGACYMaxKey

@implementation LEGACYMaxKey

- (BOOL)isEqual:(id)other {
    return other == self || ([other class] == [self class]);
}

- (NSUInteger)hash {
    return 0;
}

@end

#pragma mark LEGACYMaxKey

@implementation LEGACYMinKey

- (BOOL)isEqual:(id)other {
    return other == self || ([other class] == [self class]);
}

- (NSUInteger)hash {
    return 0;
}

@end

@implementation LEGACYMaxKey (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeMaxKey;
}

@end

@implementation LEGACYMinKey (LEGACYBSON)

- (LEGACYBSONType)bsonType {
    return LEGACYBSONTypeMinKey;
}

@end

#pragma mark LEGACYBSONToBson

Bson LEGACYConvertRLMBSONToBson(id<LEGACYBSON> b) {
    switch ([b bsonType]) {
        case LEGACYBSONTypeString:
            return ((NSString *)b).UTF8String;
        case LEGACYBSONTypeInt32:
            return ((NSNumber *)b).intValue;
        case LEGACYBSONTypeInt64:
            return ((NSNumber *)b).longLongValue;
        case LEGACYBSONTypeObjectId:
            return [((LEGACYObjectId *)b) value];
        case LEGACYBSONTypeNull:
            return util::none;
        case LEGACYBSONTypeBool:
            return (bool)((NSNumber *)b).boolValue;
        case LEGACYBSONTypeDouble:
            return ((NSNumber *)b).doubleValue;
        case LEGACYBSONTypeBinary:
            return std::vector<char>((char*)((NSData *)b).bytes,
                                     ((char*)((NSData *)b).bytes) + (int)((NSData *)b).length);
        case LEGACYBSONTypeTimestamp:
            // This represents a value of `Timestamp` in a MongoDB Collection.
            return MongoTimestamp(((NSDate *)b).timeIntervalSince1970, 0);
        case LEGACYBSONTypeDatetime:
            // This represents a value of `Date` in a MongoDB Collection.
            return LEGACYTimestampForNSDate((NSDate *)b);
        case LEGACYBSONTypeDecimal128:
            return [((LEGACYDecimal128 *)b) decimal128Value];
        case LEGACYBSONTypeRegularExpression:
            return [((NSRegularExpression *)b) regularExpressionValue];
        case LEGACYBSONTypeMaxKey:
            return max_key;
        case LEGACYBSONTypeMinKey:
            return min_key;
        case LEGACYBSONTypeDocument:
            return [((NSDictionary *)b) bsonDocumentValue];
        case LEGACYBSONTypeArray:
            return [((NSArray *)b) bsonArrayValue];
        case LEGACYBSONTypeUUID:
            return [((NSUUID *)b) rlm_uuidValue];
    }
}

BsonDocument LEGACYConvertRLMBSONArrayToBsonDocument(NSArray<id<LEGACYBSON>> *array) {
    BsonDocument bsonDocument = BsonDocument{};
    for (NSDictionary<NSString *, id<LEGACYBSON>> *item in array) {
        [item enumerateKeysAndObjectsUsingBlock:[&](NSString *key, id<LEGACYBSON> bson, BOOL *) {
            bsonDocument[key.UTF8String] = LEGACYConvertRLMBSONToBson(bson);
        }];
    }
    return bsonDocument;
}

#pragma mark BsonToLEGACYBSON

id<LEGACYBSON> LEGACYConvertBsonToRLMBSON(const Bson& b) {
    switch (b.type()) {
        case realm::bson::Bson::Type::Null:
            return [NSNull null];
        case realm::bson::Bson::Type::Int32:
            return @(static_cast<int32_t>(b));
        case realm::bson::Bson::Type::Int64:
            return @(static_cast<int64_t>(b));
        case realm::bson::Bson::Type::Bool:
            return @(static_cast<bool>(b));
        case realm::bson::Bson::Type::Double:
            return @(static_cast<double>(b));
        case realm::bson::Bson::Type::String:
            return @(static_cast<std::string>(b).c_str());
        case realm::bson::Bson::Type::Binary:
            return [[NSData alloc] initWithBsonBinary:static_cast<std::vector<char>>(b)];
        case realm::bson::Bson::Type::Timestamp:
            return [[NSDate alloc] initWithTimeIntervalSince1970:static_cast<MongoTimestamp>(b).seconds];
        case realm::bson::Bson::Type::Datetime:
            return [[NSDate alloc] initWithTimeIntervalSince1970:static_cast<Timestamp>(b).get_seconds()];
        case realm::bson::Bson::Type::ObjectId:
            return [[LEGACYObjectId alloc] initWithValue:static_cast<ObjectId>(b)];
        case realm::bson::Bson::Type::Decimal128:
            return [[LEGACYDecimal128 alloc] initWithDecimal128:static_cast<Decimal128>(b)];
        case realm::bson::Bson::Type::RegularExpression:
            return [[NSRegularExpression alloc] initWithRegularExpression:static_cast<RegularExpression>(b)];
        case realm::bson::Bson::Type::MaxKey:
            return [LEGACYMaxKey new];
        case realm::bson::Bson::Type::MinKey:
            return [LEGACYMinKey new];
        case realm::bson::Bson::Type::Document:
            return [[NSMutableDictionary alloc] initWithBsonDocument:static_cast<BsonDocument>(b)];
        case realm::bson::Bson::Type::Array:
            return [[NSMutableArray alloc] initWithBsonArray:static_cast<BsonArray>(b)];
        case realm::bson::Bson::Type::Uuid:
            return [[NSUUID alloc] initWithRealmUUID:static_cast<realm::UUID>(b)];
    }
    return nil;
}

id<LEGACYBSON> LEGACYConvertBsonDocumentToRLMBSON(std::optional<BsonDocument> b) {
    return b ? LEGACYConvertBsonToRLMBSON(*b) : nil;
}

NSArray<id<LEGACYBSON>> *LEGACYConvertBsonDocumentToRLMBSONArray(std::optional<BsonDocument> b) {
    if (!b) {
        return @[];
    }
    NSMutableArray<id<LEGACYBSON>> *array = [[NSMutableArray alloc] init];
    for (const auto& [key, value] : *b) {
        [array addObject:@{@(key.c_str()): LEGACYConvertBsonToRLMBSON(value)}];
    }
    return array;
}
