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

#import "LEGACYUtil.hpp"

#import "LEGACYArray_Private.hpp"
#import "LEGACYAccessor.hpp"
#import "LEGACYDecimal128_Private.hpp"
#import "LEGACYDictionary_Private.h"
#import "LEGACYError_Private.hpp"
#import "LEGACYObjectId_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYSwiftValueStorage.h"
#import "LEGACYSchema_Private.h"
#import "LEGACYSet_Private.hpp"
#import "LEGACYSwiftCollectionBase.h"
#import "LEGACYSwiftSupport.h"
#import "LEGACYUUID_Private.hpp"
#import "LEGACYValue.h"

#import <realm/mixed.hpp>
#import <realm/util/overload.hpp>

#include <sys/sysctl.h>
#include <sys/types.h>

#if !defined(REALM_COCOA_VERSION)
#import "LEGACYVersion.h"
#endif

static inline LEGACYArray *asLEGACYArray(__unsafe_unretained id const value) {
    return LEGACYDynamicCast<LEGACYArray>(value) ?: LEGACYDynamicCast<LEGACYSwiftCollectionBase>(value)._rlmCollection;
}

static inline LEGACYSet *asLEGACYSet(__unsafe_unretained id const value) {
    return LEGACYDynamicCast<LEGACYSet>(value) ?: LEGACYDynamicCast<LEGACYSwiftCollectionBase>(value)._rlmCollection;
}

static inline LEGACYDictionary *asLEGACYDictionary(__unsafe_unretained id const value) {
    return LEGACYDynamicCast<LEGACYDictionary>(value) ?: LEGACYDynamicCast<LEGACYSwiftCollectionBase>(value)._rlmCollection;
}

static inline bool checkCollectionType(__unsafe_unretained id<LEGACYCollection> const collection,
                                  LEGACYPropertyType type,
                                  bool optional,
                                  __unsafe_unretained NSString *const objectClassName) {
    return collection.type == type && collection.optional == optional
        && (type != LEGACYPropertyTypeObject || [collection.objectClassName isEqualToString:objectClassName]);
}

static id (*s_bridgeValue)(id);
id<NSFastEnumeration> LEGACYAsFastEnumeration(__unsafe_unretained id obj) {
    if (!obj) {
        return nil;
    }
    if ([obj conformsToProtocol:@protocol(NSFastEnumeration)]) {
        return obj;
    }
    if (s_bridgeValue) {
        id bridged = s_bridgeValue(obj);
        if ([bridged conformsToProtocol:@protocol(NSFastEnumeration)]) {
            return bridged;
        }
    }
    return nil;
}

void LEGACYSetSwiftBridgeCallback(id (*callback)(id)) {
    s_bridgeValue = callback;
}

id LEGACYBridgeSwiftValue(__unsafe_unretained id value) {
    if (!value || !s_bridgeValue) {
        return nil;
    }
    return s_bridgeValue(value);
}

bool LEGACYIsSwiftObjectClass(Class cls) {
    return [cls isSubclassOfClass:RealmSwiftLegacyObject.class]
        || [cls isSubclassOfClass:RealmSwiftLegacyEmbeddedObject.class];
}

static BOOL validateValue(__unsafe_unretained id const value,
                          LEGACYPropertyType type,
                          bool optional,
                          bool collection,
                          __unsafe_unretained NSString *const objectClassName) {
    if (optional && !LEGACYCoerceToNil(value)) {
        return YES;
    }

    if (collection) {
        if (auto rlmArray = asLEGACYArray(value)) {
            return checkCollectionType(rlmArray, type, optional, objectClassName);
        }
        else if (auto rlmSet = asLEGACYSet(value)) {
            return checkCollectionType(rlmSet, type, optional, objectClassName);
        }
        else if (auto rlmDictionary = asLEGACYDictionary(value)) {
            return checkCollectionType(rlmDictionary, type, optional, objectClassName);
        }
        if (id enumeration = LEGACYAsFastEnumeration(value)) {
            // check each element for compliance
            for (id el in enumeration) {
                if (!LEGACYValidateValue(el, type, optional, false, objectClassName)) {
                    return NO;
                }
            }
            return YES;
        }
        if (!value || value == NSNull.null) {
            return YES;
        }
        return NO;
    }

    switch (type) {
        case LEGACYPropertyTypeString:
            return [value isKindOfClass:[NSString class]];
        case LEGACYPropertyTypeBool:
            if ([value isKindOfClass:[NSNumber class]]) {
                return numberIsBool(value);
            }
            return NO;
        case LEGACYPropertyTypeDate:
            return [value isKindOfClass:[NSDate class]];
        case LEGACYPropertyTypeInt:
            if (NSNumber *number = LEGACYDynamicCast<NSNumber>(value)) {
                return numberIsInteger(number);
            }
            return NO;
        case LEGACYPropertyTypeFloat:
            if (NSNumber *number = LEGACYDynamicCast<NSNumber>(value)) {
                return numberIsFloat(number);
            }
            return NO;
        case LEGACYPropertyTypeDouble:
            if (NSNumber *number = LEGACYDynamicCast<NSNumber>(value)) {
                return numberIsDouble(number);
            }
            return NO;
        case LEGACYPropertyTypeData:
            return [value isKindOfClass:[NSData class]];
        case LEGACYPropertyTypeAny: {
            return !value
                || [value conformsToProtocol:@protocol(LEGACYValue)];
        }
        case LEGACYPropertyTypeLinkingObjects:
            return YES;
        case LEGACYPropertyTypeObject: {
            // only NSNull, nil, or objects which derive from LEGACYObject and match the given
            // object class are valid
            LEGACYObjectBase *objBase = LEGACYDynamicCast<LEGACYObjectBase>(value);
            return objBase && [objBase->_objectSchema.className isEqualToString:objectClassName];
        }
        case LEGACYPropertyTypeObjectId:
            return [value isKindOfClass:[LEGACYObjectId class]];
        case LEGACYPropertyTypeDecimal128:
            return [value isKindOfClass:[NSNumber class]]
                || [value isKindOfClass:[LEGACYDecimal128 class]]
                || ([value isKindOfClass:[NSString class]] && realm::Decimal128::is_valid_str([value UTF8String]));
        case LEGACYPropertyTypeUUID:
            return [value isKindOfClass:[NSUUID class]]
                || ([value isKindOfClass:[NSString class]] && realm::UUID::is_valid_string([value UTF8String]));
    }
    @throw LEGACYException(@"Invalid LEGACYPropertyType specified");
}

id LEGACYValidateValue(__unsafe_unretained id const value,
                    LEGACYPropertyType type, bool optional, bool collection,
                    __unsafe_unretained NSString *const objectClassName) {
    if (validateValue(value, type, optional, collection, objectClassName)) {
        return value ?: NSNull.null;
    }
    if (id bridged = LEGACYBridgeSwiftValue(value)) {
        if (validateValue(bridged, type, optional, collection, objectClassName)) {
            return bridged ?: NSNull.null;
        }
    }
    return nil;
 }


void LEGACYThrowTypeError(__unsafe_unretained id const obj,
                       __unsafe_unretained LEGACYObjectSchema *const objectSchema,
                       __unsafe_unretained LEGACYProperty *const prop) {
    @throw LEGACYException(@"Invalid value '%@' of type '%@' for '%@%s'%s property '%@.%@'.",
                        obj, [obj class],
                        prop.objectClassName ?: LEGACYTypeToString(prop.type), prop.optional ? "?" : "",
                        prop.array ? " array" : prop.set ? " set" : prop.dictionary ? " dictionary" : "", objectSchema.className, prop.name);
}

void LEGACYValidateValueForProperty(__unsafe_unretained id const obj,
                                 __unsafe_unretained LEGACYObjectSchema *const objectSchema,
                                 __unsafe_unretained LEGACYProperty *const prop,
                                 bool validateObjects) {
    // This duplicates a lot of the checks in LEGACYIsObjectValidForProperty()
    // for the sake of more specific error messages
    if (prop.collection) {
        // nil is considered equivalent to an empty array for historical reasons
        // since we don't support null arrays (only arrays containing null),
        // it's not worth the BC break to change this
        if (!obj || obj == NSNull.null) {
            return;
        }
        id enumeration = LEGACYAsFastEnumeration(obj);
        if (!enumeration) {
            @throw LEGACYException(@"Invalid value (%@) for '%@%s' %@ property '%@.%@': value is not enumerable.",
                                obj,
                                prop.objectClassName ?: LEGACYTypeToString(prop.type),
                                prop.optional ? "?" : "",
                                prop.array ? @"array" : @"set",
                                objectSchema.className, prop.name);
        }
        if (!validateObjects && prop.type == LEGACYPropertyTypeObject) {
            return;
        }

        if (LEGACYArray *array = asLEGACYArray(obj)) {
            if (!checkCollectionType(array, prop.type, prop.optional, prop.objectClassName)) {
                @throw LEGACYException(@"LEGACYArray<%@%s> does not match expected type '%@%s' for property '%@.%@'.",
                                    array.objectClassName ?: LEGACYTypeToString(array.type), array.optional ? "?" : "",
                                    prop.objectClassName ?: LEGACYTypeToString(prop.type), prop.optional ? "?" : "",
                                    objectSchema.className, prop.name);
            }
            return;
        }
        else if (LEGACYSet *set = asLEGACYSet(obj)) {
            if (!checkCollectionType(set, prop.type, prop.optional, prop.objectClassName)) {
                @throw LEGACYException(@"LEGACYSet<%@%s> does not match expected type '%@%s' for property '%@.%@'.",
                                    set.objectClassName ?: LEGACYTypeToString(set.type), set.optional ? "?" : "",
                                    prop.objectClassName ?: LEGACYTypeToString(prop.type), prop.optional ? "?" : "",
                                    objectSchema.className, prop.name);
            }
            return;
        }
        else if (LEGACYDictionary *dictionary = asLEGACYDictionary(obj)) {
            if (!checkCollectionType(dictionary, prop.type, prop.optional, prop.objectClassName)) {
                @throw LEGACYException(@"LEGACYDictionary<%@, %@%s> does not match expected type '%@%s' for property '%@.%@'.",
                                    LEGACYTypeToString(dictionary.keyType),
                                    dictionary.objectClassName ?: LEGACYTypeToString(dictionary.type), dictionary.optional ? "?" : "",
                                    prop.objectClassName ?: LEGACYTypeToString(prop.type), prop.optional ? "?" : "",
                                    objectSchema.className, prop.name);
            }
            return;
        }

        if (prop.dictionary) {
            for (id key in enumeration) {
                id value = enumeration[key];
                if (!LEGACYValidateValue(value, prop.type, prop.optional, false, prop.objectClassName)) {
                    LEGACYThrowTypeError(value, objectSchema, prop);
                }
            }
        }
        else {
            for (id value in enumeration) {
                if (!LEGACYValidateValue(value, prop.type, prop.optional, false, prop.objectClassName)) {
                    LEGACYThrowTypeError(value, objectSchema, prop);
                }
            }
        }
        return;
    }

    // For create() we want to skip the validation logic for objects because
    // we allow much fuzzier matching (any KVC-compatible object with at least
    // all the non-defaulted fields), and all the logic for that lives in the
    // object store rather than here
    if (prop.type == LEGACYPropertyTypeObject && !validateObjects) {
        return;
    }
    if (LEGACYIsObjectValidForProperty(obj, prop)) {
        return;
    }

    LEGACYThrowTypeError(obj, objectSchema, prop);
}

BOOL LEGACYIsObjectValidForProperty(__unsafe_unretained id const obj,
                                 __unsafe_unretained LEGACYProperty *const property) {
    return LEGACYValidateValue(obj, property.type, property.optional, property.collection, property.objectClassName) != nil;
}

NSDictionary *LEGACYDefaultValuesForObjectSchema(__unsafe_unretained LEGACYObjectSchema *const objectSchema) {
    if (!objectSchema.isSwiftClass) {
        return [objectSchema.objectClass defaultPropertyValues];
    }

    NSMutableDictionary *defaults = nil;
    if ([objectSchema.objectClass isSubclassOfClass:LEGACYObject.class]) {
        defaults = [NSMutableDictionary dictionaryWithDictionary:[objectSchema.objectClass defaultPropertyValues]];
    }
    else {
        defaults = [NSMutableDictionary dictionary];
    }
    LEGACYObject *defaultObject = [[objectSchema.objectClass alloc] init];
    for (LEGACYProperty *prop in objectSchema.properties) {
        if (!defaults[prop.name] && defaultObject[prop.name]) {
            defaults[prop.name] = defaultObject[prop.name];
        }
    }
    return defaults;
}

static NSException *LEGACYException(NSString *reason, NSDictionary *additionalUserInfo) {
    NSMutableDictionary *userInfo = @{LEGACYRealmVersionKey: REALM_COCOA_VERSION,
                                      LEGACYRealmCoreVersionKey: @REALM_VERSION}.mutableCopy;
    if (additionalUserInfo != nil) {
        [userInfo addEntriesFromDictionary:additionalUserInfo];
    }
    NSException *e = [NSException exceptionWithName:LEGACYExceptionName
                                             reason:reason
                                           userInfo:userInfo];
    return e;
}

NSException *LEGACYException(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSException *e = LEGACYException([[NSString alloc] initWithFormat:fmt arguments:args], @{});
    va_end(args);
    return e;
}

NSException *LEGACYException(std::exception const& exception) {
    return LEGACYException(@"%s", exception.what());
}

NSException *LEGACYException(realm::Exception const& exception) {
    return LEGACYException(@(exception.what()),
                        @{@"Error Code": @(exception.code()),
                          @"Underlying": makeError(exception.to_status())});
}

void LEGACYSetErrorOrThrow(NSError *error, NSError **outError) {
    if (outError) {
        *outError = error;
    }
    else {
        @throw LEGACYException(error.localizedDescription, @{NSUnderlyingErrorKey: error});
    }
}

BOOL LEGACYIsDebuggerAttached()
{
    int name[] = {
        CTL_KERN,
        KERN_PROC,
        KERN_PROC_PID,
        getpid()
    };

    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    if (sysctl(name, sizeof(name)/sizeof(name[0]), &info, &info_size, NULL, 0) == -1) {
        NSLog(@"sysctl() failed: %s", strerror(errno));
        return false;
    }

    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

BOOL LEGACYIsRunningInPlayground() {
    return [[NSBundle mainBundle].bundleIdentifier hasPrefix:@"com.apple.dt.playground."];
}

realm::Mixed LEGACYObjcToMixed(__unsafe_unretained id const value,
                            __unsafe_unretained LEGACYRealm *const realm,
                            realm::CreatePolicy createPolicy) {
    if (!value || value == NSNull.null) {
        return realm::Mixed();
    }
    id v;
    if ([value conformsToProtocol:@protocol(LEGACYValue)]) {
        v = value;
    }
    else {
        v = LEGACYBridgeSwiftValue(value);
        if (v == NSNull.null) {
            return realm::Mixed();
        }
        REALM_ASSERT([v conformsToProtocol:@protocol(LEGACYValue)]);
    }

    LEGACYPropertyType type = [v rlm_valueType];
    return switch_on_type(static_cast<realm::PropertyType>(type), realm::util::overload{[&](realm::Obj*) {
        // The LEGACYObjectBase may be unmanaged and therefor has no LEGACYClassInfo attached.
        // So we fetch from the Realm instead.
        // If the Object is managed use it's LEGACYClassInfo instead so we do not have to do a
        // lookup in the table of schemas.
        LEGACYObjectBase *objBase = v;
        LEGACYAccessorContext c{objBase->_info ? *objBase->_info : realm->_info[objBase->_objectSchema.className]};
        auto obj = c.unbox<realm::Obj>(v, createPolicy);
        return obj.is_valid() ? realm::Mixed(obj) : realm::Mixed();
    }, [&](auto t) {
        LEGACYStatelessAccessorContext c;
        return realm::Mixed(c.unbox<std::decay_t<decltype(*t)>>(v));
    }, [&](realm::Mixed*) -> realm::Mixed {
        REALM_UNREACHABLE();
    }});
}

id LEGACYMixedToObjc(realm::Mixed const& mixed,
                  __unsafe_unretained LEGACYRealm *realm,
                  LEGACYClassInfo *classInfo) {
    if (mixed.is_null()) {
        return NSNull.null;
    }
    switch (mixed.get_type()) {
        case realm::type_String:
            return LEGACYStringDataToNSString(mixed.get_string());
        case realm::type_Int:
            return @(mixed.get_int());
        case realm::type_Float:
            return @(mixed.get_float());
        case realm::type_Double:
            return @(mixed.get_double());
        case realm::type_Bool:
            return @(mixed.get_bool());
        case realm::type_Timestamp:
            return LEGACYTimestampToNSDate(mixed.get_timestamp());
        case realm::type_Binary:
            return LEGACYBinaryDataToNSData(mixed.get<realm::BinaryData>());
        case realm::type_Decimal:
            return [[LEGACYDecimal128 alloc] initWithDecimal128:mixed.get<realm::Decimal128>()];
        case realm::type_ObjectId:
            return [[LEGACYObjectId alloc] initWithValue:mixed.get<realm::ObjectId>()];
        case realm::type_TypedLink:
            return LEGACYObjectFromObjLink(realm, mixed.get<realm::ObjLink>(), classInfo->isSwiftClass());
        case realm::type_Link: {
            auto obj = classInfo->table()->get_object((mixed).get<realm::ObjKey>());
            return LEGACYCreateObjectAccessor(*classInfo, std::move(obj));
        }
        case realm::type_UUID:
            return [[NSUUID alloc] initWithRealmUUID:mixed.get<realm::UUID>()];
        case realm::type_LinkList:
            REALM_UNREACHABLE();
        default:
            @throw LEGACYException(@"Invalid data type for LEGACYPropertyTypeAny property.");
    }
}

realm::UUID LEGACYObjcToUUID(__unsafe_unretained id const value) {
    try {
        if (auto uuid = LEGACYDynamicCast<NSUUID>(value)) {
            return uuid.rlm_uuidValue;
        }
        if (auto string = LEGACYDynamicCast<NSString>(value)) {
            return realm::UUID(string.UTF8String);
        }
    }
    catch (std::exception const& e) {
        @throw LEGACYException(@"Cannot convert value '%@' of type '%@' to uuid: %s",
                            value, [value class], e.what());
    }
    @throw LEGACYException(@"Cannot convert value '%@' of type '%@' to uuid", value, [value class]);
}

realm::Decimal128 LEGACYObjcToDecimal128(__unsafe_unretained id const value) {
    try {
        if (!value || value == NSNull.null) {
            return realm::Decimal128(realm::null());
        }
        if (auto decimal = LEGACYDynamicCast<LEGACYDecimal128>(value)) {
            return decimal.decimal128Value;
        }
        if (auto string = LEGACYDynamicCast<NSString>(value)) {
            return realm::Decimal128(string.UTF8String);
        }
        if (auto decimal = LEGACYDynamicCast<NSDecimalNumber>(value)) {
            return realm::Decimal128(decimal.stringValue.UTF8String);
        }
        if (auto number = LEGACYDynamicCast<NSNumber>(value)) {
            auto type = number.objCType[0];
            if (type == *@encode(double) || type == *@encode(float)) {
                return realm::Decimal128(number.doubleValue);
            }
            else if (std::isupper(type)) {
                return realm::Decimal128(number.unsignedLongLongValue);
            }
            else {
                return realm::Decimal128(number.longLongValue);
            }
        }
        if (id bridged = LEGACYBridgeSwiftValue(value); bridged != value) {
            return LEGACYObjcToDecimal128(bridged);
        }
    }
    catch (std::exception const& e) {
        @throw LEGACYException(@"Cannot convert value '%@' of type '%@' to decimal128: %s",
                            value, [value class], e.what());
    }
    @throw LEGACYException(@"Cannot convert value '%@' of type '%@' to decimal128", value, [value class]);
}

NSString *LEGACYDefaultDirectoryForBundleIdentifier(NSString *bundleIdentifier) {
#if TARGET_OS_TV
    (void)bundleIdentifier;
    // tvOS prohibits writing to the Documents directory, so we use the Library/Caches directory instead.
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
#elif TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST
    (void)bundleIdentifier;
    // On iOS the Documents directory isn't user-visible, so put files there
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
#else
    // On OS X it is, so put files in Application Support. If we aren't running
    // in a sandbox, put it in a subdirectory based on the bundle identifier
    // to avoid accidentally sharing files between applications
    NSString *path = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0];
    if (![[NSProcessInfo processInfo] environment][@"APP_SANDBOX_CONTAINER_ID"]) {
        if (!bundleIdentifier) {
            bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
        }
        if (!bundleIdentifier) {
            bundleIdentifier = [NSBundle mainBundle].executablePath.lastPathComponent;
        }

        path = [path stringByAppendingPathComponent:bundleIdentifier];

        // create directory
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
    return path;
#endif
}

NSDateFormatter *LEGACYISO8601Formatter() {
    // note: NSISO8601DateFormatter can't be used as it doesn't support milliseconds
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
    dateFormatter.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    return dateFormatter;
}
