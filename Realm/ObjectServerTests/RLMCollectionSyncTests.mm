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

#import "LEGACYSyncTestCase.h"

#if TARGET_OS_OSX

// Each of these test suites compares either Person or non-realm-object values
#define LEGACYAssertEqual(lft, rgt) do { \
    if (isObject) { \
        XCTAssertEqualObjects(lft.firstName, \
                              ((Person *)rgt).firstName); \
    } else { \
        XCTAssertEqualObjects(lft, rgt); \
    } \
} while (0)

#pragma mark LEGACYSet Sync Tests

@interface LEGACYSetObjectServerTests : LEGACYSyncTestCase
@end

@implementation LEGACYSetObjectServerTests
- (NSArray *)defaultObjectTypes {
    return @[LEGACYSetSyncObject.self, Person.self];
}

- (void)roundTripWithPropertyGetter:(LEGACYSet *(^)(id))propertyGetter
                             values:(NSArray *)values
                otherPropertyGetter:(LEGACYSet *(^)(id))otherPropertyGetter
                        otherValues:(NSArray *)otherValues
                           isObject:(BOOL)isObject {
    LEGACYRealm *readRealm = [self openRealm];
    LEGACYRealm *writeRealm = [self openRealm];
    auto write = [&](auto fn) {
        [writeRealm transactionWithBlock:^{
            fn();
        }];
        [self waitForUploadsForRealm:writeRealm];
        [self waitForDownloadsForRealm:readRealm];
    };

    CHECK_COUNT(0, LEGACYSetSyncObject, readRealm);

    __block LEGACYSetSyncObject *writeObj;
    write(^{
        writeObj = [LEGACYSetSyncObject createInRealm:writeRealm
                                         withValue:@{@"_id": [LEGACYObjectId objectId]}];
    });
    CHECK_COUNT(1, LEGACYSetSyncObject, readRealm);

    write(^{
        [propertyGetter(writeObj) addObjects:values];
        [otherPropertyGetter(writeObj) addObjects:otherValues];
    });
    CHECK_COUNT(1, LEGACYSetSyncObject, readRealm);
    LEGACYResults<LEGACYSetSyncObject *> *results = [LEGACYSetSyncObject allObjectsInRealm:readRealm];
    LEGACYSetSyncObject *obj = results.firstObject;
    LEGACYSet<Person *> *set = propertyGetter(obj);
    LEGACYSet<Person *> *otherSet = otherPropertyGetter(obj);
    XCTAssertEqual(set.count, values.count);
    XCTAssertEqual(otherSet.count, otherValues.count);

    write(^{
        if (isObject) {
            [propertyGetter(writeObj) removeAllObjects];
            [propertyGetter(writeObj) addObject:values[0]];
        } else {
            [propertyGetter(writeObj) intersectSet:otherPropertyGetter(writeObj)];
        }
    });
    CHECK_COUNT(1, LEGACYSetSyncObject, readRealm);
    if (!isObject) {
        XCTAssertTrue([propertyGetter(obj) intersectsSet:propertyGetter(obj)]);
        XCTAssertEqual(propertyGetter(obj).count, 1U);
    }

    write(^{
        [propertyGetter(writeObj) removeAllObjects];
        [otherPropertyGetter(writeObj) removeAllObjects];
    });
    XCTAssertEqual(propertyGetter(obj).count, 0U);
    XCTAssertEqual(otherPropertyGetter(obj).count, 0U);
}

- (void)testIntSet {
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.intSet; }
                               values:@[@123, @234, @345]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherIntSet; }
                          otherValues:@[@345, @567, @789]
                             isObject:NO];
}

- (void)testStringSet {
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.stringSet; }
                               values:@[@"Who", @"What", @"When"]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherStringSet; }
                          otherValues:@[@"When", @"Strings", @"Collide"]
                             isObject:NO];
}

- (void)testDataSet {
    NSData* (^createData)(size_t) = ^(size_t size) {
        void *buffer = malloc(size);
        arc4random_buf(buffer, size);
        return [NSData dataWithBytesNoCopy:buffer length:size freeWhenDone:YES];
    };

    NSData *duplicateData = createData(1024U);
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.dataSet; }
                               values:@[duplicateData, createData(1024U), createData(1024U)]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherDataSet; }
                          otherValues:@[duplicateData, createData(1024U), createData(1024U)]
                             isObject:NO];
}

- (void)testDoubleSet {
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.doubleSet; }
                               values:@[@123.456, @234.456, @345.567]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherDoubleSet; }
                          otherValues:@[@123.456, @434.456, @545.567]
                             isObject:NO];
}

- (void)testObjectIdSet {
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.objectIdSet; }
                               values:@[[[LEGACYObjectId alloc] initWithString:@"6058f12b957ba06156586a7c" error:nil],
                                        [[LEGACYObjectId alloc] initWithString:@"6058f12682b2fbb1f334ef1d" error:nil],
                                        [[LEGACYObjectId alloc] initWithString:@"6058f12d42e5a393e67538d0" error:nil]]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherObjectIdSet; }
                          otherValues:@[[[LEGACYObjectId alloc] initWithString:@"6058f12b957ba06156586a7c" error:nil],
                                        [[LEGACYObjectId alloc] initWithString:@"6058f12682b2fbb1f334ef1e" error:nil],
                                        [[LEGACYObjectId alloc] initWithString:@"6058f12d42e5a393e67538df" error:nil]]
                             isObject:NO];
}

- (void)testDecimalSet {
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.decimalSet; }
                               values:@[[[LEGACYDecimal128 alloc] initWithNumber:@123.456],
                                        [[LEGACYDecimal128 alloc] initWithNumber:@223.456],
                                        [[LEGACYDecimal128 alloc] initWithNumber:@323.456]]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherDecimalSet; }
                          otherValues:@[[[LEGACYDecimal128 alloc] initWithNumber:@123.456],
                                        [[LEGACYDecimal128 alloc] initWithNumber:@423.456],
                                        [[LEGACYDecimal128 alloc] initWithNumber:@523.456]]
                             isObject:NO];
}

- (void)testUUIDSet {
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.uuidSet; }
                               values:@[[[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fd"],
                                        [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fe"],
                                        [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90ff"]]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherUuidSet; }
                          otherValues:@[[[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fd"],
                                        [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90ae"],
                                        [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90bf"]]
                             isObject:NO];
}

- (void)testObjectSet {
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.objectSet; }
                               values:@[[Person john], [Person paul], [Person ringo]]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherObjectSet; }
                          otherValues:@[[Person john], [Person paul], [Person ringo]]
                             isObject:YES];
}

- (void)testAnySet {
    [self roundTripWithPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.anySet; }
                               values:@[@123, @"Hey", NSNull.null]
                  otherPropertyGetter:^LEGACYSet *(LEGACYSetSyncObject *obj) { return obj.otherAnySet; }
                          otherValues:@[[[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fd"],
                                        @123,
                                        [[LEGACYObjectId alloc] initWithString:@"6058f12682b2fbb1f334ef1d" error:nil]]
                             isObject:NO];
}

@end

#pragma mark LEGACYArray Sync Tests

@interface LEGACYArrayObjectServerTests : LEGACYSyncTestCase
@end

@implementation LEGACYArrayObjectServerTests
- (NSArray *)defaultObjectTypes {
    return @[LEGACYArraySyncObject.self, Person.self];
}

- (void)roundTripWithPropertyGetter:(LEGACYArray *(^)(id))propertyGetter
                             values:(NSArray *)values
                           isObject:(BOOL)isObject {
    LEGACYRealm *readRealm = [self openRealm];
    LEGACYRealm *writeRealm = [self openRealm];
    auto write = [&](auto fn) {
        [writeRealm transactionWithBlock:^{
            fn();
        }];
        [self waitForUploadsForRealm:writeRealm];
        [self waitForDownloadsForRealm:readRealm];
    };

    CHECK_COUNT(0, LEGACYArraySyncObject, readRealm);
    __block LEGACYArraySyncObject *writeObj;
    write(^{
        writeObj = [LEGACYArraySyncObject createInRealm:writeRealm
                                           withValue:@{@"_id": [LEGACYObjectId objectId]}];
    });
    CHECK_COUNT(1, LEGACYArraySyncObject, readRealm);

    write(^{
        [propertyGetter(writeObj) addObjects:values];
        [propertyGetter(writeObj) addObjects:values];
    });
    CHECK_COUNT(1, LEGACYArraySyncObject, readRealm);
    LEGACYResults<LEGACYArraySyncObject *> *results = [LEGACYArraySyncObject allObjectsInRealm:readRealm];
    LEGACYArraySyncObject *obj = results.firstObject;
    LEGACYArray<Person *> *array = propertyGetter(obj);
    XCTAssertEqual(array.count, values.count*2);
    for (NSUInteger i = 0; i < values.count; i++) {
        LEGACYAssertEqual(array[i], values[i]);
    }

    write(^{
        [propertyGetter(writeObj) removeLastObject];
        [propertyGetter(writeObj) removeLastObject];
        [propertyGetter(writeObj) removeLastObject];
    });
    XCTAssertEqual(propertyGetter(obj).count, values.count);

    write(^{
        [propertyGetter(writeObj) replaceObjectAtIndex:0
                                            withObject:values[1]];
    });
    LEGACYAssertEqual(array[0], values[1]);
}

- (void)testIntArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.intArray; }
                               values:@[@123, @234, @345]
                             isObject:NO];
}

- (void)testBoolArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.boolArray; }
                               values:@[@YES, @NO, @YES]
                             isObject:NO];
}

- (void)testStringArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.stringArray; }
                               values:@[@"Hello...", @"It's", @"Me"]
                             isObject:NO];
}

- (void)testDataArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.dataArray; }
                               values:@[[NSData dataWithBytes:(unsigned char[]){0x0a}
                                                       length:1],
                                        [NSData dataWithBytes:(unsigned char[]){0x0b}
                                                       length:1],
                                        [NSData dataWithBytes:(unsigned char[]){0x0c}
                                                       length:1]]
                             isObject:NO];
}

- (void)testDoubleArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.doubleArray; }
                               values:@[@123.456, @789.456, @987.344]
                             isObject:NO];
}

- (void)testObjectIdArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.objectIdArray; }
                               values:@[[[LEGACYObjectId alloc] initWithString:@"6058f12b957ba06156586a7c" error:nil],
                                        [[LEGACYObjectId alloc] initWithString:@"6058f12682b2fbb1f334ef1d" error:nil],
                                        [[LEGACYObjectId alloc] initWithString:@"6058f12d42e5a393e67538d0" error:nil]]
                             isObject:NO];
}

- (void)testDecimalArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.decimalArray; }
                               values:@[[[LEGACYDecimal128 alloc] initWithNumber:@123.456],
                                        [[LEGACYDecimal128 alloc] initWithNumber:@456.456],
                                        [[LEGACYDecimal128 alloc] initWithNumber:@789.456]]
                             isObject:NO];
}

- (void)testUUIDArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.uuidArray; }
                               values:@[[[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fd"],
                                        [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fe"],
                                        [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90ff"]]
                             isObject:NO];
}

- (void)testObjectArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.objectArray; }
                               values:@[[Person john], [Person paul], [Person ringo]]
                             isObject:YES];
}

- (void)testAnyArray {
    [self roundTripWithPropertyGetter:^LEGACYArray *(LEGACYArraySyncObject *obj) { return obj.anyArray; }
                               values:@[@1234, @"I'm a String", NSNull.null]
                             isObject:NO];
}

@end

#pragma mark LEGACYDictionary Sync Tests

@interface LEGACYDictionaryObjectServerTests : LEGACYSyncTestCase
@end

@implementation LEGACYDictionaryObjectServerTests
- (NSArray *)defaultObjectTypes {
    return @[LEGACYDictionarySyncObject.self, Person.self];
}

- (void)roundTripWithPropertyGetter:(LEGACYDictionary *(^)(id))propertyGetter
                             values:(NSDictionary *)values
                           isObject:(BOOL)isObject {
    LEGACYRealm *readRealm = [self openRealm];
    LEGACYRealm *writeRealm = [self openRealm];
    auto write = [&](auto fn) {
        [writeRealm transactionWithBlock:^{
            fn();
        }];
        [self waitForUploadsForRealm:writeRealm];
        [self waitForDownloadsForRealm:readRealm];
    };

    CHECK_COUNT(0, LEGACYDictionarySyncObject, readRealm);

    __block LEGACYDictionarySyncObject *writeObj;
    write(^{
        writeObj = [LEGACYDictionarySyncObject createInRealm:writeRealm
                                                withValue:@{@"_id": [LEGACYObjectId objectId]}];
    });
    CHECK_COUNT(1, LEGACYDictionarySyncObject, readRealm);

    write(^{
        [propertyGetter(writeObj) addEntriesFromDictionary:values];
    });
    CHECK_COUNT(1, LEGACYDictionarySyncObject, readRealm);
    LEGACYResults<LEGACYDictionarySyncObject *> *results = [LEGACYDictionarySyncObject allObjectsInRealm:readRealm];
    LEGACYDictionarySyncObject *obj = results.firstObject;
    LEGACYDictionary<NSString *, Person *> *dict = propertyGetter(obj);
    XCTAssertEqual(dict.count, values.count);
    for (NSString *key in values) {
        LEGACYAssertEqual(dict[key], values[key]);
    }

    write(^{
        int i = 0;
        LEGACYDictionary *dict = propertyGetter(writeObj);
        for (NSString *key in dict) {
            dict[key] = nil;
            if (++i >= 3) {
                break;
            }
        }
    });
    CHECK_COUNT(1, LEGACYDictionarySyncObject, readRealm);
    XCTAssertEqual(dict.count, 2U);

    write(^{
        LEGACYDictionary *dict = propertyGetter(writeObj);
        NSArray *keys = dict.allKeys;
        dict[keys[0]] = dict[keys[1]];
    });
    CHECK_COUNT(1, LEGACYDictionarySyncObject, readRealm);
    XCTAssertEqual(dict.count, 2U);
    NSArray *keys = dict.allKeys;
    LEGACYAssertEqual(dict[keys[0]], dict[keys[1]]);
}

- (void)testIntDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.intDictionary; }
                               values:@{@"0": @123, @"1": @234, @"2": @345, @"3": @567, @"4": @789}
                             isObject:NO];
}
- (void)testStringDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.stringDictionary; }
                               values:@{@"0": @"Who", @"1": @"What", @"2": @"When", @"3": @"Strings", @"4": @"Collide"}
                             isObject:NO];
}

- (void)testDataDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.dataDictionary; }
                               values:@{@"0": [NSData dataWithBytes:(unsigned char[]){0x0a} length:1],
                                        @"1": [NSData dataWithBytes:(unsigned char[]){0x0b} length:1],
                                        @"2": [NSData dataWithBytes:(unsigned char[]){0x0c} length:1],
                                        @"3": [NSData dataWithBytes:(unsigned char[]){0x0d} length:1],
                                        @"4": [NSData dataWithBytes:(unsigned char[]){0x0e} length:1]}
                             isObject:NO];
}

- (void)testDoubleDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.doubleDictionary; }
                               values:@{@"0": @123.456, @"1": @234.456, @"2": @345.567, @"3": @434.456, @"4": @545.567}
                             isObject:NO];
}

- (void)testObjectIdDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.objectIdDictionary; }
                               values:@{@"0": [[LEGACYObjectId alloc] initWithString:@"6058f12b957ba06156586a7c" error:nil],
                                        @"1": [[LEGACYObjectId alloc] initWithString:@"6058f12682b2fbb1f334ef1d" error:nil],
                                        @"2": [[LEGACYObjectId alloc] initWithString:@"6058f12d42e5a393e67538d0" error:nil],
                                        @"3": [[LEGACYObjectId alloc] initWithString:@"6058f12682b2fbb1f334ef1e" error:nil],
                                        @"4": [[LEGACYObjectId alloc] initWithString:@"6058f12d42e5a393e67538df" error:nil]}
                             isObject:NO];
}

- (void)testDecimalDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.decimalDictionary; }
                               values:@{@"0": [[LEGACYDecimal128 alloc] initWithNumber:@123.456],
                                        @"1": [[LEGACYDecimal128 alloc] initWithNumber:@223.456],
                                        @"2": [[LEGACYDecimal128 alloc] initWithNumber:@323.456],
                                        @"3": [[LEGACYDecimal128 alloc] initWithNumber:@423.456],
                                        @"4": [[LEGACYDecimal128 alloc] initWithNumber:@523.456]}
                             isObject:NO];
}

- (void)testUUIDDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.uuidDictionary; }
                               values:@{@"0": [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fd"],
                                        @"1": [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fe"],
                                        @"2": [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90ff"],
                                        @"3": [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90ae"],
                                        @"4": [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90bf"]}
                             isObject:NO];
}

- (void)testObjectDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.objectDictionary; }
                               values:@{@"0": [Person john],
                                        @"1": [Person paul],
                                        @"2": [Person ringo],
                                        @"3": [Person george],
                                        @"4": [Person stuart]}
                             isObject:YES];
}

- (void)testAnyDictionary {
    [self roundTripWithPropertyGetter:^LEGACYDictionary *(LEGACYDictionarySyncObject *obj) { return obj.anyDictionary; }
                               values:@{@"0": @123,
                                        @"1": @"Hey",
                                        @"2": NSNull.null,
                                        @"3": [[NSUUID alloc] initWithUUIDString:@"6b28ec45-b29a-4b0a-bd6a-343c7f6d90fd"],
                                        @"4": [[LEGACYObjectId alloc] initWithString:@"6058f12682b2fbb1f334ef1d" error:nil]}
                             isObject:NO];
}
@end

#endif // TARGET_OS_OSX
