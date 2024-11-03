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
#import "LEGACYUUID_Private.hpp"

#import <realm/util/bson/bson.hpp>

#import <XCTest/XCTest.h>

using namespace realm::bson;

@interface LEGACYBSONTestCase : XCTestCase

@end

@implementation LEGACYBSONTestCase

- (void)testNilRoundTrip {
    auto bson = Bson();
    id<LEGACYBSON> rlm = LEGACYConvertBsonToRLMBSON(bson);
    XCTAssertEqual(rlm, [NSNull null]);
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testIntRoundTrip {
    auto bson = Bson(int64_t(42));
    NSNumber *rlm = (NSNumber *)LEGACYConvertBsonToRLMBSON(bson);
    XCTAssertEqual(rlm.intValue, 42);
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testBoolRoundTrip {
    auto bson = Bson(true);
    NSNumber *rlm = (NSNumber *)LEGACYConvertBsonToRLMBSON(bson);
    XCTAssertEqual(rlm.boolValue, true);
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testDoubleRoundTrip {
    auto bson = Bson(42.42);
    NSNumber *rlm = (NSNumber *)LEGACYConvertBsonToRLMBSON(bson);
    XCTAssertEqual(rlm.doubleValue, 42.42);
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testStringRoundTrip {
    auto bson = Bson("foo");
    NSString *rlm = (NSString *)LEGACYConvertBsonToRLMBSON(bson);
    XCTAssertEqualObjects(rlm, @"foo");
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testBinaryRoundTrip {
    auto bson = Bson(std::vector<char>{1, 2, 3});
    NSData *rlm = (NSData *)LEGACYConvertBsonToRLMBSON(bson);
    NSData *d = [[NSData alloc] initWithBytes:(char[]){1, 2, 3} length:3];
    XCTAssert([rlm isEqualToData: d]);
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testDatetimeMongoTimestampRoundTrip {
    auto bson = Bson(realm::Timestamp(42, 0));
    NSDate *rlm = (NSDate *)LEGACYConvertBsonToRLMBSON(bson);
    NSDate *d = [[NSDate alloc] initWithTimeIntervalSince1970:42];
    XCTAssert([rlm isEqualToDate: d]);
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testDatetimeTimestampRoundTrip {
    auto bson = Bson(realm::Timestamp(42, 0));
    NSDate *rlm = (NSDate *)LEGACYConvertBsonToRLMBSON(bson);
    NSDate *d = [[NSDate alloc] initWithTimeIntervalSince1970:42];
    XCTAssert([rlm isEqualToDate: d]);
    // Not an exact round trip since we ignore Timestamp Cocoa side
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), Bson(realm::Timestamp(42, 0)));
}

- (void)testObjectIdRoundTrip {
    auto bson = Bson(realm::ObjectId::gen());
    LEGACYObjectId *rlm = (LEGACYObjectId *)LEGACYConvertBsonToRLMBSON(bson);
    LEGACYObjectId *d = [[LEGACYObjectId alloc] initWithString:rlm.stringValue error:nil];
    XCTAssertEqualObjects(rlm, d);
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testUUIDRoundTrip {
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"b1c11e54-e719-4275-b631-69ec3f2d616d"];
    auto bson = Bson(uuid.rlm_uuidValue);
    NSUUID *rlm = (NSUUID *)LEGACYConvertBsonToRLMBSON(bson);
    XCTAssertEqualObjects(rlm, uuid);
    XCTAssertEqual(LEGACYConvertRLMBSONToBson(rlm), bson);
}

- (void)testDocumentRoundTrip {
    NSDictionary<NSString *, id<LEGACYBSON>> *document = @{
        @"nil": [NSNull null],
        @"string": @"test string",
        @"true": @YES,
        @"false": @NO,
        @"int": @25,
        @"int32": @5,
        @"int64": @10,
        @"double": @15.0,
        @"decimal128": [[LEGACYDecimal128 alloc] initWithString:@"1.2E+10" error:nil],
        @"minkey": [LEGACYMinKey new],
        @"maxkey": [LEGACYMaxKey new],
        @"date": [[NSDate alloc] initWithTimeIntervalSince1970: 500],
        @"nestedarray": @[@[@1, @2], @[@3, @4]],
        @"nesteddoc": @{@"a": @1, @"b": @2, @"c": @NO, @"d": @[@3, @4], @"e" : @{@"f": @"g"}},
        @"oid": [[LEGACYObjectId alloc] initWithString:@"507f1f77bcf86cd799439011" error:nil],
        @"regex": [[NSRegularExpression alloc] initWithPattern:@"^abc" options:0 error:nil],
        @"array1": @[@1, @2],
        @"array2": @[@"string1", @"string2"],
        @"uuid": [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"],
    };
    
    auto bson = LEGACYConvertRLMBSONToBson(document);
    
    auto bsonDocument = static_cast<BsonDocument>(bson);

    XCTAssertEqual(document[@"nil"], [NSNull null]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["nil"]), document[@"nil"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["string"]), document[@"string"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["true"]), document[@"true"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["false"]), document[@"false"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["int"]), document[@"int"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["int32"]), document[@"int32"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["int64"]), document[@"int64"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["double"]), document[@"double"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["decimal128"]), document[@"decimal128"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["minkey"]), document[@"minkey"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["maxkey"]), document[@"maxkey"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["date"]), document[@"date"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["nestedarray"]), document[@"nestedarray"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["nesteddoc"]), document[@"nesteddoc"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["oid"]), document[@"oid"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["regex"]), document[@"regex"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["array1"]), document[@"array1"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["array2"]), document[@"array2"]);
    XCTAssertEqualObjects(LEGACYConvertBsonToRLMBSON(bsonDocument["uuid"]), document[@"uuid"]);
}

@end
