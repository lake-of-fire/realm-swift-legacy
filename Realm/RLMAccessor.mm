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

#import "LEGACYAccessor.hpp"

#import "LEGACYArray_Private.hpp"
#import "LEGACYDictionary_Private.hpp"
#import "LEGACYObjectId_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYObservation.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYResults_Private.hpp"
#import "LEGACYSchema_Private.h"
#import "LEGACYSet_Private.hpp"
#import "LEGACYSwiftProperty.h"
#import "LEGACYUUID_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/results.hpp>
#import <realm/object-store/property.hpp>

#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark Helper functions

using realm::ColKey;

namespace realm {
template<>
Obj Obj::get<Obj>(ColKey col) const {
    ObjKey key = get<ObjKey>(col);
    return key ? get_target_table(col)->get_object(key) : Obj();
}

} // namespace realm

namespace {
realm::Property const& getProperty(__unsafe_unretained LEGACYObjectBase *const obj, NSUInteger index) {
    return obj->_info->objectSchema->persisted_properties[index];
}

realm::Property const& getProperty(__unsafe_unretained LEGACYObjectBase *const obj,
                                   __unsafe_unretained LEGACYProperty *const prop) {
    if (prop.linkOriginPropertyName) {
        return obj->_info->objectSchema->computed_properties[prop.index];
    }
    return obj->_info->objectSchema->persisted_properties[prop.index];
}

template<typename T>
bool isNull(T const& v) {
    return !v;
}
template<>
bool isNull(realm::Timestamp const& v) {
    return v.is_null();
}
template<>
bool isNull(realm::ObjectId const&) {
    return false;
}
template<>
bool isNull(realm::Decimal128 const& v) {
    return v.is_null();
}
template<>
bool isNull(realm::Mixed const& v) {
    return v.is_null();
}
template<>
bool isNull(realm::UUID const&) {
    return false;
}

template<typename T>
T get(__unsafe_unretained LEGACYObjectBase *const obj, NSUInteger index) {
    LEGACYVerifyAttached(obj);
    return obj->_row.get<T>(getProperty(obj, index).column_key);
}

template<typename T>
id getBoxed(__unsafe_unretained LEGACYObjectBase *const obj, NSUInteger index) {
    LEGACYVerifyAttached(obj);
    auto& prop = getProperty(obj, index);
    LEGACYAccessorContext ctx(obj, &prop);
    auto value = obj->_row.get<T>(prop.column_key);
    return isNull(value) ? nil : ctx.box(std::move(value));
}

template<typename T>
T getOptional(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key, bool *gotValue) {
    auto ret = get<std::optional<T>>(obj, key);
    if (ret) {
        *gotValue = true;
    }
    return ret.value_or(T{});
}

template<typename T>
void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key, T val) {
    obj->_row.set(key, val);
}

template<typename T>
void setValueOrNull(__unsafe_unretained LEGACYObjectBase *const obj, ColKey col,
                    __unsafe_unretained id const value) {
    LEGACYVerifyInWriteTransaction(obj);

    LEGACYTranslateError([&] {
        if (value) {
            if constexpr (std::is_same_v<T, realm::Mixed>) {
                obj->_row.set(col, LEGACYObjcToMixed(value, obj->_realm, realm::CreatePolicy::SetLink));
            }
            else {
                LEGACYStatelessAccessorContext ctx;
                obj->_row.set(col, ctx.unbox<T>(value));
            }
        }
        else {
            obj->_row.set_null(col);
        }
    });
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj,
              ColKey key, __unsafe_unretained NSDate *const date) {
    setValueOrNull<realm::Timestamp>(obj, key, date);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained NSData *const value) {
    setValueOrNull<realm::BinaryData>(obj, key, value);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained NSString *const value) {
    setValueOrNull<realm::StringData>(obj, key, value);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained LEGACYObjectBase *const val) {
    if (!val) {
        obj->_row.set(key, realm::null());
        return;
    }

    if (!val->_row) {
        LEGACYAccessorContext{obj, key}.createObject(val, {.create = true}, false, {});
    }

    // make sure it is the correct type
    auto table = val->_row.get_table();
    if (table != obj->_row.get_table()->get_link_target(key)) {
        @throw LEGACYException(@"Can't set object of type '%@' to property of type '%@'",
                            val->_objectSchema.className,
                            obj->_info->propertyForTableColumn(key).objectClassName);
    }
    if (!table->is_embedded()) {
        obj->_row.set(key, val->_row.get_key());
    }
    else if (obj->_row.get_linked_object(key).get_key() != val->_row.get_key()) {
        @throw LEGACYException(@"Can't set link to existing managed embedded object");
    }
}

id LEGACYCollectionClassForProperty(LEGACYProperty *prop, bool isManaged) {
    Class cls = nil;
    if (prop.array) {
        cls = isManaged ? [LEGACYManagedArray class] : [LEGACYArray class];
    } else if (prop.set) {
        cls = isManaged ? [LEGACYManagedSet class] : [LEGACYSet class];
    } else if (prop.dictionary) {
        cls = isManaged ? [LEGACYManagedDictionary class] : [LEGACYDictionary class];
    } else {
        @throw LEGACYException(@"Invalid collection '%@' for class '%@'.",
                            prop.name, prop.objectClassName);
    }
    return cls;
}

// collection getter/setter
id<LEGACYCollection> getCollection(__unsafe_unretained LEGACYObjectBase *const obj, NSUInteger propIndex) {
    LEGACYVerifyAttached(obj);
    auto prop = obj->_info->rlmObjectSchema.properties[propIndex];
    Class cls = LEGACYCollectionClassForProperty(prop, true);
    return [[cls alloc] initWithParent:obj property:prop];
}

template <typename Collection>
void assignValue(__unsafe_unretained LEGACYObjectBase *const obj,
                 __unsafe_unretained LEGACYProperty *const prop,
                 ColKey key,
                 __unsafe_unretained id<NSFastEnumeration> const value) {
    auto info = obj->_info;
    Collection collection(obj->_realm->_realm, obj->_row, key);
    if (collection.get_type() == realm::PropertyType::Object) {
        info = &obj->_info->linkTargetType(prop.index);
    }
    LEGACYAccessorContext ctx(*info);
    LEGACYTranslateError([&] {
        collection.assign(ctx, value, realm::CreatePolicy::ForceCreate);
    });
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained id<NSFastEnumeration> const value) {
    auto prop = obj->_info->propertyForTableColumn(key);
    LEGACYValidateValueForProperty(value, obj->_info->rlmObjectSchema, prop, true);

    if (prop.array) {
        assignValue<realm::List>(obj, prop, key, value);
    }
    else if (prop.set) {
        assignValue<realm::object_store::Set>(obj, prop, key, value);
    }
    else if (prop.dictionary) {
        assignValue<realm::object_store::Dictionary>(obj, prop, key, value);
    }
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained NSNumber<LEGACYInt> *const intObject) {
    setValueOrNull<int64_t>(obj, key, intObject);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained NSNumber<LEGACYFloat> *const floatObject) {
    setValueOrNull<float>(obj, key, floatObject);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained NSNumber<LEGACYDouble> *const doubleObject) {
    setValueOrNull<double>(obj, key, doubleObject);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained NSNumber<LEGACYBool> *const boolObject) {
    setValueOrNull<bool>(obj, key, boolObject);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained LEGACYDecimal128 *const value) {
    setValueOrNull<realm::Decimal128>(obj, key, value);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained LEGACYObjectId *const value) {
    setValueOrNull<realm::ObjectId>(obj, key, value);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained NSUUID *const value) {
    setValueOrNull<realm::UUID>(obj, key, value);
}

void setValue(__unsafe_unretained LEGACYObjectBase *const obj, ColKey key,
              __unsafe_unretained id<LEGACYValue> const value) {
    setValueOrNull<realm::Mixed>(obj, key, value);
}

LEGACYLinkingObjects *getLinkingObjects(__unsafe_unretained LEGACYObjectBase *const obj,
                                     __unsafe_unretained LEGACYProperty *const property) {
    LEGACYVerifyAttached(obj);
    auto& objectInfo = obj->_realm->_info[property.objectClassName];
    auto& linkOrigin = obj->_info->objectSchema->computed_properties[property.index].link_origin_property_name;
    auto linkingProperty = objectInfo.objectSchema->property_for_name(linkOrigin);
    auto backlinkView = obj->_row.get_backlink_view(objectInfo.table(), linkingProperty->column_key);
    realm::Results results(obj->_realm->_realm, std::move(backlinkView));
    return [LEGACYLinkingObjects resultsWithObjectInfo:objectInfo results:std::move(results)];
}

// any getter/setter
template<typename Type, typename StorageType=Type>
id makeGetter(NSUInteger index) {
    return ^(__unsafe_unretained LEGACYObjectBase *const obj) {
        return static_cast<Type>(get<StorageType>(obj, index));
    };
}

template<typename Type>
id makeBoxedGetter(NSUInteger index) {
    return ^(__unsafe_unretained LEGACYObjectBase *const obj) {
        return getBoxed<Type>(obj, index);
    };
}
template<typename Type>
id makeOptionalGetter(NSUInteger index) {
    return ^(__unsafe_unretained LEGACYObjectBase *const obj) {
        return getBoxed<std::optional<Type>>(obj, index);
    };
}
template<typename Type>
id makeNumberGetter(NSUInteger index, bool boxed, bool optional) {
    if (optional) {
        return makeOptionalGetter<Type>(index);
    }
    if (boxed) {
        return makeBoxedGetter<Type>(index);
    }
    return makeGetter<Type>(index);
}
template<typename Type>
id makeWrapperGetter(NSUInteger index, bool optional) {
    if (optional) {
        return makeOptionalGetter<Type>(index);
    }
    return makeBoxedGetter<Type>(index);
}

// dynamic getter with column closure
id managedGetter(LEGACYProperty *prop, const char *type) {
    NSUInteger index = prop.index;
    if (prop.collection && prop.type != LEGACYPropertyTypeLinkingObjects) {
        return ^id(__unsafe_unretained LEGACYObjectBase *const obj) {
            return getCollection(obj, index);
        };
    }

    bool boxed = *type == '@';
    switch (prop.type) {
        case LEGACYPropertyTypeInt:
            if (prop.optional || boxed) {
                return makeNumberGetter<long long>(index, boxed, prop.optional);
            }
            switch (*type) {
                case 'c': return makeGetter<char, int64_t>(index);
                case 's': return makeGetter<short, int64_t>(index);
                case 'i': return makeGetter<int, int64_t>(index);
                case 'l': return makeGetter<long, int64_t>(index);
                case 'q': return makeGetter<long long, int64_t>(index);
                default:
                    @throw LEGACYException(@"Unexpected property type for Objective-C type code");
            }
        case LEGACYPropertyTypeFloat:
            return makeNumberGetter<float>(index, boxed, prop.optional);
        case LEGACYPropertyTypeDouble:
            return makeNumberGetter<double>(index, boxed, prop.optional);
        case LEGACYPropertyTypeBool:
            return makeNumberGetter<bool>(index, boxed, prop.optional);
        case LEGACYPropertyTypeString:
            return makeBoxedGetter<realm::StringData>(index);
        case LEGACYPropertyTypeDate:
            return makeBoxedGetter<realm::Timestamp>(index);
        case LEGACYPropertyTypeData:
            return makeBoxedGetter<realm::BinaryData>(index);
        case LEGACYPropertyTypeObject:
            return makeBoxedGetter<realm::Obj>(index);
        case LEGACYPropertyTypeDecimal128:
            return makeBoxedGetter<realm::Decimal128>(index);
        case LEGACYPropertyTypeObjectId:
            return makeWrapperGetter<realm::ObjectId>(index, prop.optional);
        case LEGACYPropertyTypeAny:
            // Mixed is represented as optional in Core,
            // but not in Cocoa. We use `makeBoxedGetter` over
            // `makeWrapperGetter` becuase Mixed can box a `null` representation.
            return makeBoxedGetter<realm::Mixed>(index);
        case LEGACYPropertyTypeLinkingObjects:
            return ^(__unsafe_unretained LEGACYObjectBase *const obj) {
                return getLinkingObjects(obj, prop);
            };
        case LEGACYPropertyTypeUUID:
            return makeWrapperGetter<realm::UUID>(index, prop.optional);
    }
}

static realm::ColKey willChange(LEGACYObservationTracker& tracker,
                                __unsafe_unretained LEGACYObjectBase *const obj, NSUInteger index) {
    auto& prop = getProperty(obj, index);
    if (prop.is_primary) {
        @throw LEGACYException(@"Primary key can't be changed after an object is inserted.");
    }
    tracker.willChange(LEGACYGetObservationInfo(obj->_observationInfo, obj->_row.get_key(), *obj->_info),
                       obj->_objectSchema.properties[index].name);
    return prop.column_key;
}

template<typename ArgType, typename StorageType=ArgType>
void kvoSetValue(__unsafe_unretained LEGACYObjectBase *const obj, NSUInteger index, ArgType value) {
    LEGACYVerifyInWriteTransaction(obj);
    LEGACYObservationTracker tracker(obj->_realm);
    auto key = willChange(tracker, obj, index);
    if constexpr (std::is_same_v<ArgType, LEGACYObjectBase *>) {
        tracker.trackDeletions();
    }
    setValue(obj, key, static_cast<StorageType>(value));
}

template<typename ArgType, typename StorageType=ArgType>
id makeSetter(__unsafe_unretained LEGACYProperty *const prop) {
    if (prop.isPrimary) {
        return ^(__unused LEGACYObjectBase *obj, __unused ArgType val) {
            @throw LEGACYException(@"Primary key can't be changed after an object is inserted.");
        };
    }

    NSUInteger index = prop.index;
    return ^(__unsafe_unretained LEGACYObjectBase *const obj, ArgType val) {
        kvoSetValue<ArgType, StorageType>(obj, index, val);
    };
}

// dynamic setter with column closure
id managedSetter(LEGACYProperty *prop, const char *type) {
    if (prop.collection && prop.type != LEGACYPropertyTypeLinkingObjects) {
        return makeSetter<id<NSFastEnumeration>>(prop);
    }

    bool boxed = prop.optional || *type == '@';
    switch (prop.type) {
        case LEGACYPropertyTypeInt:
            if (boxed) {
                return makeSetter<NSNumber<LEGACYInt> *>(prop);
            }
            switch (*type) {
                case 'c': return makeSetter<char, long long>(prop);
                case 's': return makeSetter<short, long long>(prop);
                case 'i': return makeSetter<int, long long>(prop);
                case 'l': return makeSetter<long, long long>(prop);
                case 'q': return makeSetter<long long>(prop);
                default:
                    @throw LEGACYException(@"Unexpected property type for Objective-C type code");
            }
        case LEGACYPropertyTypeFloat:
            return boxed ? makeSetter<NSNumber<LEGACYFloat> *>(prop) : makeSetter<float>(prop);
        case LEGACYPropertyTypeDouble:
            return boxed ? makeSetter<NSNumber<LEGACYDouble> *>(prop) : makeSetter<double>(prop);
        case LEGACYPropertyTypeBool:
            return boxed ? makeSetter<NSNumber<LEGACYBool> *>(prop) : makeSetter<BOOL, bool>(prop);
        case LEGACYPropertyTypeString:         return makeSetter<NSString *>(prop);
        case LEGACYPropertyTypeDate:           return makeSetter<NSDate *>(prop);
        case LEGACYPropertyTypeData:           return makeSetter<NSData *>(prop);
        case LEGACYPropertyTypeAny:            return makeSetter<id<LEGACYValue>>(prop);
        case LEGACYPropertyTypeLinkingObjects: return nil;
        case LEGACYPropertyTypeObject:         return makeSetter<LEGACYObjectBase *>(prop);
        case LEGACYPropertyTypeObjectId:       return makeSetter<LEGACYObjectId *>(prop);
        case LEGACYPropertyTypeDecimal128:     return makeSetter<LEGACYDecimal128 *>(prop);
        case LEGACYPropertyTypeUUID:           return makeSetter<NSUUID *>(prop);
    }
}

// call getter for superclass for property at key
id superGet(LEGACYObjectBase *obj, NSString *propName) {
    typedef id (*getter_type)(LEGACYObjectBase *, SEL);
    LEGACYProperty *prop = obj->_objectSchema[propName];
    Class superClass = class_getSuperclass(obj.class);
    getter_type superGetter = (getter_type)[superClass instanceMethodForSelector:prop.getterSel];
    return superGetter(obj, prop.getterSel);
}

// call setter for superclass for property at key
void superSet(LEGACYObjectBase *obj, NSString *propName, id val) {
    typedef void (*setter_type)(LEGACYObjectBase *, SEL, id<LEGACYCollection> collection);
    LEGACYProperty *prop = obj->_objectSchema[propName];
    Class superClass = class_getSuperclass(obj.class);
    setter_type superSetter = (setter_type)[superClass instanceMethodForSelector:prop.setterSel];
    superSetter(obj, prop.setterSel, val);
}

// getter/setter for unmanaged object
id unmanagedGetter(LEGACYProperty *prop, const char *) {
    // only override getters for LEGACYCollection and linking objects properties
    if (prop.type == LEGACYPropertyTypeLinkingObjects) {
        return ^(LEGACYObjectBase *) { return [LEGACYResults emptyDetachedResults]; };
    }
    if (prop.collection) {
        NSString *propName = prop.name;
        Class cls = LEGACYCollectionClassForProperty(prop, false);
        if (prop.type == LEGACYPropertyTypeObject) {
            NSString *objectClassName = prop.objectClassName;
            LEGACYPropertyType keyType = prop.dictionaryKeyType;
            return ^(LEGACYObjectBase *obj) {
                id val = superGet(obj, propName);
                if (!val) {
                    val = [[cls alloc] initWithObjectClassName:objectClassName keyType:keyType];
                    superSet(obj, propName, val);
                }
                return val;
            };
        }
        auto type = prop.type;
        auto optional = prop.optional;
        auto dictionaryKeyType = prop.dictionaryKeyType;
        return ^(LEGACYObjectBase *obj) {
            id val = superGet(obj, propName);
            if (!val) {
                val = [[cls alloc] initWithObjectType:type optional:optional keyType:dictionaryKeyType];
                superSet(obj, propName, val);
            }
            return val;
        };
    }
    return nil;
}

id unmanagedSetter(LEGACYProperty *prop, const char *) {
    // Only LEGACYCollection types need special handling for the unmanaged setter
    if (!prop.collection) {
        return nil;
    }

    NSString *propName = prop.name;
    return ^(LEGACYObjectBase *obj, id<NSFastEnumeration> values) {
        auto prop = obj->_objectSchema[propName];
        LEGACYValidateValueForProperty(values, obj->_objectSchema, prop, true);

        Class cls = LEGACYCollectionClassForProperty(prop, false);
        id collection;
            // make copy when setting (as is the case for all other variants)
        if (prop.type == LEGACYPropertyTypeObject) {
            collection = [[cls alloc] initWithObjectClassName:prop.objectClassName keyType:prop.dictionaryKeyType];
        }
        else {
            collection = [[cls alloc] initWithObjectType:prop.type optional:prop.optional keyType:prop.dictionaryKeyType];
        }

        if (prop.dictionary)
            [collection addEntriesFromDictionary:(id)values];
        else
            [collection addObjects:values];
        superSet(obj, propName, collection);
    };
}

void addMethod(Class cls, __unsafe_unretained LEGACYProperty *const prop,
               id (*getter)(LEGACYProperty *, const char *),
               id (*setter)(LEGACYProperty *, const char *)) {
    SEL sel = prop.getterSel;
    if (!sel) {
        return;
    }
    auto getterMethod = class_getInstanceMethod(cls, sel);
    if (!getterMethod) {
        return;
    }

    const char *getterType = method_getTypeEncoding(getterMethod);
    if (id block = getter(prop, getterType)) {
        class_addMethod(cls, sel, imp_implementationWithBlock(block), getterType);
    }

    if (!(sel = prop.setterSel)) {
        return;
    }
    auto setterMethod = class_getInstanceMethod(cls, sel);
    if (!setterMethod) {
        return;
    }
    if (id block = setter(prop, getterType)) { // note: deliberately getterType as it's easier to grab the relevant type from
        class_addMethod(cls, sel, imp_implementationWithBlock(block), method_getTypeEncoding(setterMethod));
    }
}

Class createAccessorClass(Class objectClass,
                          LEGACYObjectSchema *schema,
                          const char *accessorClassName,
                          id (*getterGetter)(LEGACYProperty *, const char *),
                          id (*setterGetter)(LEGACYProperty *, const char *)) {
    REALM_ASSERT_DEBUG(LEGACYIsObjectOrSubclass(objectClass));

    // create and register proxy class which derives from object class
    Class accClass = objc_allocateClassPair(objectClass, accessorClassName, 0);
    if (!accClass) {
        // Class with that name already exists, so just return the pre-existing one
        // This should only happen for our standalone "accessors"
        return objc_lookUpClass(accessorClassName);
    }

    // override getters/setters for each propery
    for (LEGACYProperty *prop in schema.properties) {
        addMethod(accClass, prop, getterGetter, setterGetter);
    }
    for (LEGACYProperty *prop in schema.computedProperties) {
        addMethod(accClass, prop, getterGetter, setterGetter);
    }

    objc_registerClassPair(accClass);

    return accClass;
}

bool requiresUnmanagedAccessor(LEGACYObjectSchema *schema) {
    for (LEGACYProperty *prop in schema.properties) {
        if (prop.collection && !prop.swiftIvar) {
            return true;
        }
    }
    for (LEGACYProperty *prop in schema.computedProperties) {
        if (prop.collection && !prop.swiftIvar) {
            return true;
        }
    }
    return false;
}
} // anonymous namespace

#pragma mark - Public Interface

Class LEGACYManagedAccessorClassForObjectClass(Class objectClass, LEGACYObjectSchema *schema, const char *name) {
    return createAccessorClass(objectClass, schema, name, managedGetter, managedSetter);
}

Class LEGACYUnmanagedAccessorClassForObjectClass(Class objectClass, LEGACYObjectSchema *schema) {
    if (!requiresUnmanagedAccessor(schema)) {
        return objectClass;
    }
    return createAccessorClass(objectClass, schema,
                               [@"RLM:Unmanaged " stringByAppendingString:schema.className].UTF8String,
                               unmanagedGetter, unmanagedSetter);
}

// implement the class method className on accessors to return the className of the
// base object
void LEGACYReplaceClassNameMethod(Class accessorClass, NSString *className) {
    Class metaClass = object_getClass(accessorClass);
    IMP imp = imp_implementationWithBlock(^(Class) { return className; });
    class_addMethod(metaClass, @selector(className), imp, "@@:");
}

// implement the shared schema method
void LEGACYReplaceSharedSchemaMethod(Class accessorClass, LEGACYObjectSchema *schema) {
    REALM_ASSERT(accessorClass != [RealmSwiftLegacyObject class]);
    Class metaClass = object_getClass(accessorClass);
    IMP imp = imp_implementationWithBlock(^(Class cls) {
        if (cls == accessorClass) {
            return schema;
        }

        // If we aren't being called directly on the class this was overridden
        // for, the class is either a subclass which we haven't initialized yet,
        // or it's a runtime-generated class which should use the parent's
        // schema. We check for the latter by checking if the immediate
        // descendent of the desired class is a class generated by us (there
        // may be further subclasses not generated by us for things like KVO).
        Class parent = class_getSuperclass(cls);
        while (parent != accessorClass) {
            cls = parent;
            parent = class_getSuperclass(cls);
        }

        static const char accessorClassPrefix[] = "RLM:";
        if (!strncmp(class_getName(cls), accessorClassPrefix, sizeof(accessorClassPrefix) - 1)) {
            return schema;
        }

        return [LEGACYSchema sharedSchemaForClass:cls];
    });
    class_addMethod(metaClass, @selector(sharedSchema), imp, "@@:");
}

void LEGACYDynamicValidatedSet(LEGACYObjectBase *obj, NSString *propName, id val) {
    LEGACYVerifyAttached(obj);
    LEGACYObjectSchema *schema = obj->_objectSchema;
    LEGACYProperty *prop = schema[propName];
    if (!prop) {
        @throw LEGACYException(@"Invalid property name '%@' for class '%@'.",
                            propName, obj->_objectSchema.className);
    }
    if (prop.isPrimary) {
        @throw LEGACYException(@"Primary key can't be changed to '%@' after an object is inserted.", val);
    }

    // Because embedded objects cannot be created directly, we accept anything
    // that can be converted to an embedded object for dynamic link set operations.
    bool is_embedded = prop.type == LEGACYPropertyTypeObject && obj->_info->linkTargetType(prop.index).rlmObjectSchema.isEmbedded;
    LEGACYValidateValueForProperty(val, schema, prop, !is_embedded);
    LEGACYDynamicSet(obj, prop, LEGACYCoerceToNil(val));
}

// Precondition: the property is not a primary key
void LEGACYDynamicSet(__unsafe_unretained LEGACYObjectBase *const obj,
                   __unsafe_unretained LEGACYProperty *const prop,
                   __unsafe_unretained id const val) {
    REALM_ASSERT_DEBUG(!prop.isPrimary);
    realm::Object o(obj->_info->realm->_realm, *obj->_info->objectSchema, obj->_row);
    LEGACYAccessorContext c(obj);
    LEGACYTranslateError([&] {
        o.set_property_value(c, getProperty(obj, prop).name, val ?: NSNull.null);
    });
}

id LEGACYDynamicGet(__unsafe_unretained LEGACYObjectBase *const obj, __unsafe_unretained LEGACYProperty *const prop) {
    if (auto accessor = prop.swiftAccessor; accessor && [obj isKindOfClass:obj->_objectSchema.objectClass]) {
        return LEGACYCoerceToNil([accessor get:prop on:obj]);
    }
    if (!obj->_realm) {
        return [obj valueForKey:prop.name];
    }

    realm::Object o(obj->_realm->_realm, *obj->_info->objectSchema, obj->_row);
    LEGACYAccessorContext c(obj);
    c.currentProperty = prop;
    return LEGACYTranslateError([&] {
        return LEGACYCoerceToNil(o.get_property_value<id>(c, getProperty(obj, prop)));
    });
}

id LEGACYDynamicGetByName(__unsafe_unretained LEGACYObjectBase *const obj,
                       __unsafe_unretained NSString *const propName) {
    LEGACYProperty *prop = obj->_objectSchema[propName];
    if (!prop) {
        @throw LEGACYException(@"Invalid property name '%@' for class '%@'.",
                            propName, obj->_objectSchema.className);
    }
    return LEGACYDynamicGet(obj, prop);
}

#pragma mark - Swift property getters and setter

#define REALM_SWIFT_PROPERTY_ACCESSOR(objc, swift, rlmtype) \
    objc LEGACYGetSwiftProperty##swift(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) { \
        return get<objc>(obj, key); \
    } \
    objc LEGACYGetSwiftProperty##swift##Optional(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key, bool *gotValue) { \
        return getOptional<objc>(obj, key, gotValue); \
    } \
    void LEGACYSetSwiftProperty##swift(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key, objc value) { \
        LEGACYVerifyAttached(obj); \
        kvoSetValue(obj, key, value); \
    }
REALM_FOR_EACH_SWIFT_PRIMITIVE_TYPE(REALM_SWIFT_PROPERTY_ACCESSOR)
#undef REALM_SWIFT_PROPERTY_ACCESSOR

#define REALM_SWIFT_PROPERTY_ACCESSOR(objc, swift, rlmtype) \
    void LEGACYSetSwiftProperty##swift(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key, objc *value) { \
        LEGACYVerifyAttached(obj); \
        kvoSetValue(obj, key, value); \
    }
REALM_FOR_EACH_SWIFT_OBJECT_TYPE(REALM_SWIFT_PROPERTY_ACCESSOR)
#undef REALM_SWIFT_PROPERTY_ACCESSOR

NSString *LEGACYGetSwiftPropertyString(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getBoxed<realm::StringData>(obj, key);
}

NSData *LEGACYGetSwiftPropertyData(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getBoxed<realm::BinaryData>(obj, key);
}

NSDate *LEGACYGetSwiftPropertyDate(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getBoxed<realm::Timestamp>(obj, key);
}

NSUUID *LEGACYGetSwiftPropertyUUID(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getBoxed<std::optional<realm::UUID>>(obj, key);
}

LEGACYObjectId *LEGACYGetSwiftPropertyObjectId(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getBoxed<std::optional<realm::ObjectId>>(obj, key);
}

LEGACYDecimal128 *LEGACYGetSwiftPropertyDecimal128(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getBoxed<realm::Decimal128>(obj, key);
}

LEGACYArray *LEGACYGetSwiftPropertyArray(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getCollection(obj, key);
}
LEGACYSet *LEGACYGetSwiftPropertySet(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getCollection(obj, key);
}
LEGACYDictionary *LEGACYGetSwiftPropertyMap(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getCollection(obj, key);
}

void LEGACYSetSwiftPropertyNil(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    LEGACYVerifyInWriteTransaction(obj);
    if (getProperty(obj, key).type == realm::PropertyType::Object) {
        kvoSetValue(obj, key, (LEGACYObjectBase *)nil);
    }
    else {
        // The type used here is arbitrary; it simply needs to be any non-object type
        kvoSetValue(obj, key, (NSNumber<LEGACYInt> *)nil);
    }
}

void LEGACYSetSwiftPropertyObject(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key,
                               __unsafe_unretained LEGACYObjectBase *const target) {
    kvoSetValue(obj, key, target);
}

LEGACYObjectBase *LEGACYGetSwiftPropertyObject(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getBoxed<realm::Obj>(obj, key);
}

void LEGACYSetSwiftPropertyAny(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key,
                            __unsafe_unretained id<LEGACYValue> const value) {
    kvoSetValue(obj, key, value);
}

id<LEGACYValue> LEGACYGetSwiftPropertyAny(__unsafe_unretained LEGACYObjectBase *const obj, uint16_t key) {
    return getBoxed<realm::Mixed>(obj, key);
}

#pragma mark - LEGACYAccessorContext

LEGACYAccessorContext::~LEGACYAccessorContext() = default;

LEGACYAccessorContext::LEGACYAccessorContext(LEGACYAccessorContext& parent, realm::Obj const& obj,
                                       realm::Property const& property)
: _realm(parent._realm)
, _info(property.type == realm::PropertyType::Object ? parent._info.linkTargetType(property) : parent._info)
, _parentObject(obj)
, _parentObjectInfo(&parent._info)
, _colKey(property.column_key)
{
}

LEGACYAccessorContext::LEGACYAccessorContext(LEGACYClassInfo& info)
: _realm(info.realm), _info(info)
{
}

LEGACYAccessorContext::LEGACYAccessorContext(__unsafe_unretained LEGACYObjectBase *const parent,
                                       const realm::Property *prop)
: _realm(parent->_realm)
, _info(prop && prop->type == realm::PropertyType::Object ? parent->_info->linkTargetType(*prop)
                                                          : *parent->_info)
, _parentObject(parent->_row)
, _parentObjectInfo(parent->_info)
, _colKey(prop ? prop->column_key : ColKey{})
{
}

LEGACYAccessorContext::LEGACYAccessorContext(__unsafe_unretained LEGACYObjectBase *const parent,
                                       realm::ColKey col)
: _realm(parent->_realm)
, _info(_realm->_info[parent->_info->propertyForTableColumn(col).objectClassName])
, _parentObject(parent->_row)
, _parentObjectInfo(parent->_info)
, _colKey(col)
{
}

id LEGACYAccessorContext::defaultValue(__unsafe_unretained NSString *const key) {
    if (!_defaultValues) {
        _defaultValues = LEGACYDefaultValuesForObjectSchema(_info.rlmObjectSchema);
    }
    return _defaultValues[key];
}

id LEGACYAccessorContext::propertyValue(id obj, size_t propIndex,
                                     __unsafe_unretained LEGACYProperty *const prop) {
    obj = LEGACYBridgeSwiftValue(obj) ?: obj;

    // Property value from an NSArray
    if ([obj respondsToSelector:@selector(objectAtIndex:)]) {
        return propIndex < [obj count] ? [obj objectAtIndex:propIndex] : nil;
    }

    // Property value from an NSDictionary
    if ([obj respondsToSelector:@selector(objectForKey:)]) {
        return [obj objectForKey:prop.name];
    }

    // Property value from an instance of this object type
    if ([obj isKindOfClass:_info.rlmObjectSchema.objectClass] && prop.swiftAccessor) {
        return [prop.swiftAccessor get:prop on:obj];
    }

    // Property value from some object that's KVC-compatible
    id value = LEGACYValidatedValueForProperty(obj, [obj respondsToSelector:prop.getterSel] ? prop.getterName : prop.name,
                                            _info.rlmObjectSchema.className);
    return value ?: NSNull.null;
}

realm::Obj LEGACYAccessorContext::create_embedded_object() {
    if (!_parentObject) {
        @throw LEGACYException(@"Embedded objects cannot be created directly");
    }
    return _parentObject.create_and_set_linked_object(_colKey);
}

id LEGACYAccessorContext::box(realm::Mixed v) {
    return LEGACYMixedToObjc(v, _realm, &_info);
}

id LEGACYAccessorContext::box(realm::List&& l) {
    REALM_ASSERT(_parentObjectInfo);
    REALM_ASSERT(currentProperty);
    return [[LEGACYManagedArray alloc] initWithBackingCollection:std::move(l)
                                                   parentInfo:_parentObjectInfo
                                                     property:currentProperty];
}

id LEGACYAccessorContext::box(realm::object_store::Set&& s) {
    REALM_ASSERT(_parentObjectInfo);
    REALM_ASSERT(currentProperty);
    return [[LEGACYManagedSet alloc] initWithBackingCollection:std::move(s)
                                                 parentInfo:_parentObjectInfo
                                                   property:currentProperty];
}

id LEGACYAccessorContext::box(realm::object_store::Dictionary&& d) {
    REALM_ASSERT(_parentObjectInfo);
    REALM_ASSERT(currentProperty);
    return [[LEGACYManagedDictionary alloc] initWithBackingCollection:std::move(d)
                                                        parentInfo:_parentObjectInfo
                                                          property:currentProperty];
}

id LEGACYAccessorContext::box(realm::Object&& o) {
    REALM_ASSERT(currentProperty);
    return LEGACYCreateObjectAccessor(_info.linkTargetType(currentProperty.index), o.get_obj());
}

id LEGACYAccessorContext::box(realm::Obj&& r) {
    if (!currentProperty) {
        // If currentProperty is set, then we're reading from a Collection and
        // that reported an audit read for us. If not, we need to report the
        // audit read. This happens automatically when creating a
        // `realm::Object`, but our object accessors don't wrap that type.
        realm::Object(_realm->_realm, *_info.objectSchema, r, _parentObject, _colKey);
    }
    return LEGACYCreateObjectAccessor(_info, std::move(r));
}

id LEGACYAccessorContext::box(realm::Results&& r) {
    REALM_ASSERT(currentProperty);
    return [LEGACYResults resultsWithObjectInfo:_realm->_info[currentProperty.objectClassName]
                                     results:std::move(r)];
}

using realm::ObjKey;
using realm::CreatePolicy;

template<typename T>
static T *bridged(__unsafe_unretained id const value) {
    return [value isKindOfClass:[T class]] ? value : LEGACYBridgeSwiftValue(value);
}

template<>
realm::Timestamp LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const value) {
    id v = LEGACYCoerceToNil(value);
    return LEGACYTimestampForNSDate(bridged<NSDate>(v));
}

template<>
bool LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return [bridged<NSNumber>(v) boolValue];
}
template<>
double LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return [bridged<NSNumber>(v) doubleValue];
}
template<>
float LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return [bridged<NSNumber>(v) floatValue];
}
template<>
long long LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return [bridged<NSNumber>(v) longLongValue];
}
template<>
realm::BinaryData LEGACYStatelessAccessorContext::unbox(id v) {
    v = LEGACYCoerceToNil(v);
    return LEGACYBinaryDataForNSData(bridged<NSData>(v));
}
template<>
realm::StringData LEGACYStatelessAccessorContext::unbox(id v) {
    v = LEGACYCoerceToNil(v);
    return LEGACYStringDataWithNSString(bridged<NSString>(v));
}
template<>
realm::Decimal128 LEGACYStatelessAccessorContext::unbox(id v) {
    return LEGACYObjcToDecimal128(v);
}
template<>
realm::ObjectId LEGACYStatelessAccessorContext::unbox(id v) {
    return bridged<LEGACYObjectId>(v).value;
}
template<>
realm::UUID LEGACYStatelessAccessorContext::unbox(id v) {
    return LEGACYObjcToUUID(bridged<NSUUID>(v));
}
template<>
realm::Mixed LEGACYAccessorContext::unbox(__unsafe_unretained id v, CreatePolicy p, ObjKey) {
    return LEGACYObjcToMixed(v, _realm, p);
}

template<typename T>
static auto toOptional(__unsafe_unretained id const value) {
    id v = LEGACYCoerceToNil(value);
    return v ? realm::util::make_optional(LEGACYStatelessAccessorContext::unbox<T>(v))
             : realm::util::none;
}

template<>
std::optional<bool> LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return toOptional<bool>(v);
}
template<>
std::optional<double> LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return toOptional<double>(v);
}
template<>
std::optional<float> LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return toOptional<float>(v);
}
template<>
std::optional<int64_t> LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return toOptional<int64_t>(v);
}
template<>
std::optional<realm::ObjectId> LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return toOptional<realm::ObjectId>(v);
}
template<>
std::optional<realm::UUID> LEGACYStatelessAccessorContext::unbox(__unsafe_unretained id const v) {
    return toOptional<realm::UUID>(v);
}

std::pair<realm::Obj, bool>
LEGACYAccessorContext::createObject(id value, realm::CreatePolicy policy,
                                 bool forceCreate, ObjKey existingKey) {
    if (!value || value == NSNull.null) {
        @throw LEGACYException(@"Must provide a non-nil value.");
    }

    if ([value isKindOfClass:[NSArray class]] && [value count] > _info.objectSchema->persisted_properties.size()) {
        @throw LEGACYException(@"Invalid array input: more values (%llu) than properties (%llu).",
                            (unsigned long long)[value count],
                            (unsigned long long)_info.objectSchema->persisted_properties.size());
    }

    LEGACYObjectBase *objBase = LEGACYDynamicCast<LEGACYObjectBase>(value);
    realm::Obj obj, *outObj = nullptr;
    bool requiresSwiftUIObservers = false;
    if (objBase) {
        if (objBase.isInvalidated) {
            if (policy.create && !policy.copy) {
                @throw LEGACYException(@"Adding a deleted or invalidated object to a Realm is not permitted");
            }
            else {
                @throw LEGACYException(@"Object has been deleted or invalidated.");
            }
        }
        if (policy.copy) {
            if (policy.update || !forceCreate) {
                // create(update: true) is a no-op when given an object already in
                // the Realm which is of the correct type
                if (objBase->_realm == _realm && objBase->_row.get_table() == _info.table() && !_info.table()->is_embedded()) {
                    return {objBase->_row, true};
                }
            }
            // Otherwise we copy the object
            objBase = nil;
        }
        else {
            outObj = &objBase->_row;
            // add() on an object already managed by this Realm is a no-op
            if (objBase->_realm == _realm) {
                return {objBase->_row, true};
            }
            if (!policy.create) {
                return {realm::Obj(), false};
            }
            if (objBase->_realm) {
                @throw LEGACYException(@"Object is already managed by another Realm. Use create instead to copy it into this Realm.");
            }
            if (objBase->_observationInfo && objBase->_observationInfo->hasObservers()) {
                requiresSwiftUIObservers = [LEGACYSwiftUIKVO removeObserversFromObject:objBase];
                if (!requiresSwiftUIObservers) {
                    @throw LEGACYException(@"Cannot add an object with observers to a Realm");
                }
            }

            REALM_ASSERT([objBase->_objectSchema.className isEqualToString:_info.rlmObjectSchema.className]);
            REALM_ASSERT([objBase isKindOfClass:_info.rlmObjectSchema.unmanagedClass]);

            objBase->_info = &_info;
            objBase->_realm = _realm;
            objBase->_objectSchema = _info.rlmObjectSchema;
        }
    }
    if (!policy.create) {
        return {realm::Obj(), false};
    }
    if (!outObj) {
        outObj = &obj;
    }

    try {
        realm::Object::create(*this, _realm->_realm, *_info.objectSchema,
                              (id)value, policy, existingKey, outObj);
    }
    catch (std::exception const& e) {
        @throw LEGACYException(e);
    }

    if (objBase) {
        for (LEGACYProperty *prop in _info.rlmObjectSchema.properties) {
            // set the ivars for object and array properties to nil as otherwise the
            // accessors retain objects that are no longer accessible via the properties
            // this is mainly an issue when the object graph being added has cycles,
            // as it's not obvious that the user has to set the *ivars* to nil to
            // avoid leaking memory
            if (prop.type == LEGACYPropertyTypeObject && !prop.swiftIvar) {
                ((void(*)(id, SEL, id))objc_msgSend)(objBase, prop.setterSel, nil);
            }
        }

        object_setClass(objBase, _info.rlmObjectSchema.accessorClass);
        LEGACYInitializeSwiftAccessor(objBase, true);
    }

    if (requiresSwiftUIObservers) {
        [LEGACYSwiftUIKVO addObserversToObject:objBase];
    }

    return {*outObj, false};
}

template<>
realm::Obj LEGACYAccessorContext::unbox(__unsafe_unretained id const v, CreatePolicy policy, ObjKey key) {
    return createObject(v, policy, false, key).first;
}

void LEGACYAccessorContext::will_change(realm::Obj const& row, realm::Property const& prop) {
    auto obsInfo = LEGACYGetObservationInfo(nullptr, row.get_key(), _info);
    if (!_observationHelper) {
        if (obsInfo || prop.type == realm::PropertyType::Object) {
            _observationHelper = std::make_unique<LEGACYObservationTracker>(_info.realm);
        }
    }
    if (_observationHelper) {
        _observationHelper->willChange(obsInfo, _info.propertyForTableColumn(prop.column_key).name);
        if (prop.type == realm::PropertyType::Object) {
            _observationHelper->trackDeletions();
        }
    }
}

void LEGACYAccessorContext::did_change() {
    if (_observationHelper) {
        _observationHelper->didChange();
    }
}

LEGACYOptionalId LEGACYAccessorContext::value_for_property(__unsafe_unretained id const obj,
                                                     realm::Property const&, size_t propIndex) {
    auto prop = _info.rlmObjectSchema.properties[propIndex];
    id value = propertyValue(obj, propIndex, prop);
    if (value) {
        LEGACYValidateValueForProperty(value, _info.rlmObjectSchema, prop);
    }
    return LEGACYOptionalId{value};
}

LEGACYOptionalId LEGACYAccessorContext::default_value_for_property(realm::ObjectSchema const&,
                                                             realm::Property const& prop)
{
    return LEGACYOptionalId{defaultValue(@(prop.name.c_str()))};
}

bool LEGACYStatelessAccessorContext::is_same_list(realm::List const& list,
                                               __unsafe_unretained id const v) noexcept {
    return [v respondsToSelector:@selector(isBackedByList:)] && [v isBackedByList:list];
}

bool LEGACYStatelessAccessorContext::is_same_set(realm::object_store::Set const& set,
                                              __unsafe_unretained id const v) noexcept {
    return [v respondsToSelector:@selector(isBackedBySet:)] && [v isBackedBySet:set];
}

bool LEGACYStatelessAccessorContext::is_same_dictionary(realm::object_store::Dictionary const& dict,
                                                     __unsafe_unretained id const v) noexcept {
    return [v respondsToSelector:@selector(isBackedByDictionary:)] && [v isBackedByDictionary:dict];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation LEGACYManagedPropertyAccessor
// Most types don't need to distinguish between promote and init so provide a default
+ (void)promote:(LEGACYProperty *)property on:(LEGACYObjectBase *)parent {
    [self initialize:property on:parent];
}
@end
#pragma clang diagnostic pop
