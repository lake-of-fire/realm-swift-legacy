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

#import <Realm/LEGACYConstants.h>
#import <Realm/LEGACYSwiftValueStorage.h>
#import <Realm/LEGACYValue.h>

#import <realm/array.hpp>
#import <realm/binary_data.hpp>
#import <realm/object-store/object.hpp>
#import <realm/string_data.hpp>
#import <realm/timestamp.hpp>
#import <realm/util/file.hpp>

#import <objc/runtime.h>
#import <os/lock.h>

namespace realm {
class Decimal128;
class Exception;
class Mixed;
}

class LEGACYClassInfo;

@class LEGACYObjectSchema;
@class LEGACYProperty;

__attribute__((format(NSString, 1, 2)))
NSException *LEGACYException(NSString *fmt, ...);
NSException *LEGACYException(std::exception const& exception);
NSException *LEGACYException(realm::Exception const& exception);

void LEGACYSetErrorOrThrow(NSError *error, NSError **outError);

LEGACY_HIDDEN_BEGIN

// returns if the object can be inserted as the given type
BOOL LEGACYIsObjectValidForProperty(id obj, LEGACYProperty *prop);
// throw an exception if the object is not a valid value for the property
void LEGACYValidateValueForProperty(id obj, LEGACYObjectSchema *objectSchema,
                                 LEGACYProperty *prop, bool validateObjects=false);
id LEGACYValidateValue(id value, LEGACYPropertyType type, bool optional, bool collection,
                    NSString *objectClassName);

void LEGACYThrowTypeError(id obj, LEGACYObjectSchema *objectSchema, LEGACYProperty *prop);

// gets default values for the given schema (+defaultPropertyValues)
// merges with native property defaults if Swift class
NSDictionary *LEGACYDefaultValuesForObjectSchema(LEGACYObjectSchema *objectSchema);

BOOL LEGACYIsDebuggerAttached();
BOOL LEGACYIsRunningInPlayground();

// C version of isKindOfClass
static inline BOOL LEGACYIsKindOfClass(Class class1, Class class2) {
    while (class1) {
        if (class1 == class2) return YES;
        class1 = class_getSuperclass(class1);
    }
    return NO;
}

template<typename T>
static inline T *LEGACYDynamicCast(__unsafe_unretained id obj) {
    if ([obj isKindOfClass:[T class]]) {
        return obj;
    }
    return nil;
}

static inline id LEGACYCoerceToNil(__unsafe_unretained id obj) {
    if (static_cast<id>(obj) == NSNull.null) {
        return nil;
    }
    else if (__unsafe_unretained auto optional = LEGACYDynamicCast<LEGACYSwiftValueStorage>(obj)) {
        return LEGACYCoerceToNil(LEGACYGetSwiftValueStorage(optional));
    }
    return obj;
}

template<typename T>
static inline T LEGACYCoerceToNil(__unsafe_unretained T obj) {
    return LEGACYCoerceToNil(static_cast<id>(obj));
}

id<NSFastEnumeration> LEGACYAsFastEnumeration(id obj);
id LEGACYBridgeSwiftValue(id obj);

bool LEGACYIsSwiftObjectClass(Class cls);

// String conversion utilities
static inline NSString *LEGACYStringDataToNSString(realm::StringData stringData) {
    static_assert(sizeof(NSUInteger) >= sizeof(size_t),
                  "Need runtime overflow check for size_t to NSUInteger conversion");
    if (stringData.is_null()) {
        return nil;
    }
    else {
        return [[NSString alloc] initWithBytes:stringData.data()
                                        length:stringData.size()
                                      encoding:NSUTF8StringEncoding];
    }
}

static inline NSString *LEGACYStringViewToNSString(std::string_view stringView) {
    if (stringView.size() == 0) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:stringView.data()
                                    length:stringView.size()
                                  encoding:NSUTF8StringEncoding];
}

static inline realm::StringData LEGACYStringDataWithNSString(__unsafe_unretained NSString *const string) {
    static_assert(sizeof(size_t) >= sizeof(NSUInteger),
                  "Need runtime overflow check for NSUInteger to size_t conversion");
    return realm::StringData(string.UTF8String,
                             [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

// Binary conversion utilities
static inline NSData *LEGACYBinaryDataToNSData(realm::BinaryData binaryData) {
    return binaryData ? [NSData dataWithBytes:binaryData.data() length:binaryData.size()] : nil;
}

static inline realm::BinaryData LEGACYBinaryDataForNSData(__unsafe_unretained NSData *const data) {
    // this is necessary to ensure that the empty NSData isn't treated by core as the null realm::BinaryData
    // because data.bytes == 0 when data.length == 0
    // the casting bit ensures that we create a data with a non-null pointer
    auto bytes = static_cast<const char *>(data.bytes) ?: static_cast<char *>((__bridge void *)data);
    return realm::BinaryData(bytes, data.length);
}

// Date conversion utilities
// These use the reference date and shift the seconds rather than just getting
// the time interval since the epoch directly to avoid losing sub-second precision
static inline NSDate *LEGACYTimestampToNSDate(realm::Timestamp ts) NS_RETURNS_RETAINED {
    if (ts.is_null())
        return nil;
    auto timeInterval = ts.get_seconds() - NSTimeIntervalSince1970 + ts.get_nanoseconds() / 1'000'000'000.0;
    return [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:timeInterval];
}

static inline realm::Timestamp LEGACYTimestampForNSDate(__unsafe_unretained NSDate *const date) {
    if (!date)
        return {};
    auto timeInterval = date.timeIntervalSinceReferenceDate;
    if (isnan(timeInterval))
        return {0, 0}; // Arbitrary choice

    // Clamp dates that we can't represent as a Timestamp to the maximum value
    if (timeInterval >= std::numeric_limits<int64_t>::max() - NSTimeIntervalSince1970)
        return {std::numeric_limits<int64_t>::max(), 1'000'000'000 - 1};
    if (timeInterval - NSTimeIntervalSince1970 < std::numeric_limits<int64_t>::min())
        return {std::numeric_limits<int64_t>::min(), -1'000'000'000 + 1};

    auto seconds = static_cast<int64_t>(timeInterval);
    auto nanoseconds = static_cast<int32_t>((timeInterval - seconds) * 1'000'000'000.0);
    seconds += static_cast<int64_t>(NSTimeIntervalSince1970);

    // Seconds and nanoseconds have to have the same sign
    if (nanoseconds < 0 && seconds > 0) {
        nanoseconds += 1'000'000'000;
        --seconds;
    }
    return {seconds, nanoseconds};
}

static inline NSUInteger LEGACYConvertNotFound(size_t index) {
    return index == realm::not_found ? NSNotFound : index;
}

static inline void LEGACYNSStringToStdString(std::string &out, NSString *in) {
    if (!in)
        return;
    
    out.resize([in maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    if (out.empty()) {
        return;
    }

    NSUInteger size = out.size();
    [in getBytes:&out[0]
       maxLength:size
      usedLength:&size
        encoding:NSUTF8StringEncoding
         options:0 range:{0, in.length} remainingRange:nullptr];
    out.resize(size);
}

realm::Mixed LEGACYObjcToMixed(__unsafe_unretained id value,
                            __unsafe_unretained LEGACYRealm *realm=nil,
                            realm::CreatePolicy createPolicy={});
id LEGACYMixedToObjc(realm::Mixed const& value,
                  __unsafe_unretained LEGACYRealm *realm=nil,
                  LEGACYClassInfo *classInfo=nullptr);

realm::Decimal128 LEGACYObjcToDecimal128(id value);
realm::UUID LEGACYObjcToUUID(__unsafe_unretained id const value);

// Given a bundle identifier, return the base directory on the disk within which Realm database and support files should
// be stored.
FOUNDATION_EXTERN LEGACY_VISIBLE
NSString *LEGACYDefaultDirectoryForBundleIdentifier(NSString *bundleIdentifier);

// Get a NSDateFormatter for ISO8601-formatted strings
NSDateFormatter *LEGACYISO8601Formatter();

template<typename Fn>
static auto LEGACYTranslateError(Fn&& fn) {
    try {
        return fn();
    }
    catch (std::exception const& e) {
        @throw LEGACYException(e);
    }
}

static inline bool numberIsInteger(__unsafe_unretained NSNumber *const obj) {
    char data_type = [obj objCType][0];
    return data_type == *@encode(bool) ||
           data_type == *@encode(char) ||
           data_type == *@encode(short) ||
           data_type == *@encode(int) ||
           data_type == *@encode(long) ||
           data_type == *@encode(long long) ||
           data_type == *@encode(unsigned short) ||
           data_type == *@encode(unsigned int) ||
           data_type == *@encode(unsigned long) ||
           data_type == *@encode(unsigned long long);
}

static inline bool numberIsBool(__unsafe_unretained NSNumber *const obj) {
    // @encode(BOOL) is 'B' on iOS 64 and 'c'
    // objcType is always 'c'. Therefore compare to "c".
    if ([obj objCType][0] == 'c') {
        return true;
    }

    if (numberIsInteger(obj)) {
        int value = [obj intValue];
        return value == 0 || value == 1;
    }

    return false;
}

static inline bool numberIsFloat(__unsafe_unretained NSNumber *const obj) {
    char data_type = [obj objCType][0];
    return data_type == *@encode(float) ||
           data_type == *@encode(short) ||
           data_type == *@encode(int) ||
           data_type == *@encode(long) ||
           data_type == *@encode(long long) ||
           data_type == *@encode(unsigned short) ||
           data_type == *@encode(unsigned int) ||
           data_type == *@encode(unsigned long) ||
           data_type == *@encode(unsigned long long) ||
           // A double is like float if it fits within float bounds or is NaN.
           (data_type == *@encode(double) && (ABS([obj doubleValue]) <= FLT_MAX || isnan([obj doubleValue])));
}

static inline bool numberIsDouble(__unsafe_unretained NSNumber *const obj) {
    char data_type = [obj objCType][0];
    return data_type == *@encode(double) ||
           data_type == *@encode(float) ||
           data_type == *@encode(short) ||
           data_type == *@encode(int) ||
           data_type == *@encode(long) ||
           data_type == *@encode(long long) ||
           data_type == *@encode(unsigned short) ||
           data_type == *@encode(unsigned int) ||
           data_type == *@encode(unsigned long) ||
           data_type == *@encode(unsigned long long);
}

class LEGACYUnfairMutex {
public:
    LEGACYUnfairMutex() = default;

    void lock() noexcept {
        os_unfair_lock_lock(&_lock);
    }

    bool try_lock() noexcept {
        return os_unfair_lock_trylock(&_lock);
    }

    void unlock() noexcept {
        os_unfair_lock_unlock(&_lock);
    }

private:
    os_unfair_lock _lock = OS_UNFAIR_LOCK_INIT;
    LEGACYUnfairMutex(LEGACYUnfairMutex const&) = delete;
    LEGACYUnfairMutex& operator=(LEGACYUnfairMutex const&) = delete;
};

LEGACY_HIDDEN_END
