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

#import "LEGACYObject_Private.hpp"
#import "LEGACYObjectBase_Private.h"

#import "LEGACYAccessor.h"
#import "LEGACYArray_Private.hpp"
#import "LEGACYDecimal128.h"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObservation.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYSchema_Private.h"
#import "LEGACYSet_Private.hpp"
#import "LEGACYSwiftCollectionBase.h"
#import "LEGACYSwiftSupport.h"
#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/object.hpp>
#import <realm/object-store/object_schema.hpp>
#import <realm/object-store/shared_realm.hpp>

const NSUInteger LEGACYDescriptionMaxDepth = 5;

static bool isManagedAccessorClass(Class cls) {
    const char *className = class_getName(cls);
    const char accessorClassPrefix[] = "RLM:Managed";
    return strncmp(className, accessorClassPrefix, sizeof(accessorClassPrefix) - 1) == 0;
}

static void maybeInitObjectSchemaForUnmanaged(LEGACYObjectBase *obj) {
    Class cls = obj.class;
    if (isManagedAccessorClass(cls)) {
        return;
    }

    obj->_objectSchema = [cls sharedSchema];
    if (!obj->_objectSchema) {
        return;
    }

    // set default values
    if (!obj->_objectSchema.isSwiftClass) {
        NSDictionary *dict = LEGACYDefaultValuesForObjectSchema(obj->_objectSchema);
        for (NSString *key in dict) {
            [obj setValue:dict[key] forKey:key];
        }
    }

    // set unmanaged accessor class
    object_setClass(obj, obj->_objectSchema.unmanagedClass);
}

@interface LEGACYObjectBase () <LEGACYThreadConfined, LEGACYThreadConfined_Private>
@end

@implementation LEGACYObjectBase

- (instancetype)init {
    if ((self = [super init])) {
        maybeInitObjectSchemaForUnmanaged(self);
    }
    return self;
}

- (void)dealloc {
    // This can't be a unique_ptr because associated objects are removed
    // *after* c++ members are destroyed and dealloc is called, and we need it
    // to be in a validish state when that happens
    delete _observationInfo;
    _observationInfo = nullptr;
}

static id coerceToObjectType(id obj, Class cls, LEGACYSchema *schema) {
    if ([obj isKindOfClass:cls]) {
        return obj;
    }
    obj = LEGACYBridgeSwiftValue(obj) ?: obj;
    id value = [[cls alloc] init];
    LEGACYInitializeWithValue(value, obj, schema);
    return value;
}

static id validatedObjectForProperty(__unsafe_unretained id const obj,
                                     __unsafe_unretained LEGACYObjectSchema *const objectSchema,
                                     __unsafe_unretained LEGACYProperty *const prop,
                                     __unsafe_unretained LEGACYSchema *const schema) {
    LEGACYValidateValueForProperty(obj, objectSchema, prop);
    if (!obj || obj == NSNull.null) {
        return nil;
    }
    if (prop.type == LEGACYPropertyTypeObject) {
        Class objectClass = schema[prop.objectClassName].objectClass;
        id enumerable = LEGACYAsFastEnumeration(obj);
        if (prop.dictionary) {
            NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
            for (id key in enumerable) {
                id val = LEGACYCoerceToNil(obj[key]);
                if (val) {
                    val = coerceToObjectType(obj[key], objectClass, schema);
                }
                [ret setObject:val ?: NSNull.null forKey:key];
            }
            return ret;
        }
        else if (prop.collection) {
            NSMutableArray *ret = [[NSMutableArray alloc] init];
            for (id el in enumerable) {
                [ret addObject:coerceToObjectType(el, objectClass, schema)];
            }
            return ret;
        }
        return coerceToObjectType(obj, objectClass, schema);
    }
    else if (prop.type == LEGACYPropertyTypeDecimal128 && !prop.collection) {
        return [[LEGACYDecimal128 alloc] initWithValue:obj];
    }
    return obj;
}

void LEGACYInitializeWithValue(LEGACYObjectBase *self, id value, LEGACYSchema *schema) {
    if (!value || value == NSNull.null) {
        @throw LEGACYException(@"Must provide a non-nil value.");
    }

    LEGACYObjectSchema *objectSchema = self->_objectSchema;
    if (!objectSchema) {
        // Will be nil if we're called during schema init, when we don't want
        // to actually populate the object anyway
        return;
    }

    NSArray *properties = objectSchema.properties;
    if (NSArray *array = LEGACYDynamicCast<NSArray>(value)) {
        if (array.count > properties.count) {
            @throw LEGACYException(@"Invalid array input: more values (%llu) than properties (%llu).",
                                (unsigned long long)array.count, (unsigned long long)properties.count);
        }
        NSUInteger i = 0;
        for (id val in array) {
            LEGACYProperty *prop = properties[i++];
            [self setValue:validatedObjectForProperty(LEGACYCoerceToNil(val), objectSchema, prop, schema)
                    forKey:prop.name];
        }
    }
    else {
        // assume our object is an NSDictionary or an object with kvc properties
        for (LEGACYProperty *prop in properties) {
            id obj = LEGACYValidatedValueForProperty(value, prop.name, objectSchema.className);

            // don't set unspecified properties
            if (!obj) {
                continue;
            }

            [self setValue:validatedObjectForProperty(LEGACYCoerceToNil(obj), objectSchema, prop, schema)
                    forKey:prop.name];
        }
    }
}

id LEGACYCreateManagedAccessor(Class cls, LEGACYClassInfo *info) {
    LEGACYObjectBase *obj = [[cls alloc] init];
    obj->_info = info;
    obj->_realm = info->realm;
    obj->_objectSchema = info->rlmObjectSchema;
    return obj;
}

- (id)valueForKey:(NSString *)key {
    if (_observationInfo) {
        return _observationInfo->valueForKey(key);
    }
    return [super valueForKey:key];
}

// Generic Swift properties can't be dynamic, so KVO doesn't work for them by default
- (id)valueForUndefinedKey:(NSString *)key {
    LEGACYProperty *prop = _objectSchema[key];
    if (Class swiftAccessor = prop.swiftAccessor) {
        return LEGACYCoerceToNil([swiftAccessor get:prop on:self]);
    }
    return [super valueForUndefinedKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    value = LEGACYCoerceToNil(value);
    LEGACYProperty *property = _objectSchema[key];
    if (property.collection) {
        if (id enumerable = LEGACYAsFastEnumeration(value)) {
            value = validatedObjectForProperty(value, _objectSchema, property,
                                               LEGACYSchema.partialPrivateSharedSchema);
        }
    }
    if (auto swiftAccessor = property.swiftAccessor) {
        [swiftAccessor set:property on:self to:value];
    }
    else {
        [super setValue:value forUndefinedKey:key];
    }
}

// overridden at runtime per-class for performance
+ (NSString *)className {
    NSString *className = NSStringFromClass(self);
    if ([LEGACYSwiftSupport isSwiftClassName:className]) {
        className = [LEGACYSwiftSupport demangleClassName:className];
    }
    return className;
}

// overridden at runtime per-class for performance
+ (LEGACYObjectSchema *)sharedSchema {
    return [LEGACYSchema sharedSchemaForClass:self.class];
}

+ (void)initializeLinkedObjectSchemas {
    for (LEGACYProperty *prop in self.sharedSchema.properties) {
        if (prop.type == LEGACYPropertyTypeObject && !LEGACYSchema.partialPrivateSharedSchema[prop.objectClassName]) {
            [[LEGACYSchema classForString:prop.objectClassName] initializeLinkedObjectSchemas];
        }
    }
}

+ (nullable NSArray<LEGACYProperty *> *)_getProperties {
    return nil;
}

- (NSString *)description {
    if (self.isInvalidated) {
        return @"[invalid object]";
    }

    return [self descriptionWithMaxDepth:LEGACYDescriptionMaxDepth];
}

- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth {
    if (depth == 0) {
        return @"<Maximum depth exceeded>";
    }

    NSString *baseClassName = _objectSchema.className;
    NSMutableString *mString = [NSMutableString stringWithFormat:@"%@ {\n", baseClassName];

    for (LEGACYProperty *property in _objectSchema.properties) {
        id object = [(id)self objectForKeyedSubscript:property.name];
        NSString *sub;
        if ([object respondsToSelector:@selector(descriptionWithMaxDepth:)]) {
            sub = [object descriptionWithMaxDepth:depth - 1];
        }
        else if (property.type == LEGACYPropertyTypeData) {
            static NSUInteger maxPrintedDataLength = 24;
            NSData *data = object;
            NSUInteger length = data.length;
            if (length > maxPrintedDataLength) {
                data = [NSData dataWithBytes:data.bytes length:maxPrintedDataLength];
            }
            NSString *dataDescription = [data description];
            sub = [NSString stringWithFormat:@"<%@ — %lu total bytes>", [dataDescription substringWithRange:NSMakeRange(1, dataDescription.length - 2)], (unsigned long)length];
        }
        else {
            sub = [object description];
        }
        [mString appendFormat:@"\t%@ = %@;\n", property.name, [sub stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    }
    [mString appendString:@"}"];

    return [NSString stringWithString:mString];
}

- (LEGACYRealm *)realm {
    return _realm;
}

- (LEGACYObjectSchema *)objectSchema {
    return _objectSchema;
}

- (BOOL)isInvalidated {
    // if not unmanaged and our accessor has been detached, we have been deleted
    return _info && !_row.is_valid();
}

- (BOOL)isEqual:(id)object {
    if (LEGACYObjectBase *other = LEGACYDynamicCast<LEGACYObjectBase>(object)) {
        if (_objectSchema.primaryKeyProperty || _realm.isFrozen) {
            return LEGACYObjectBaseAreEqual(self, other);
        }
    }
    return [super isEqual:object];
}

- (NSUInteger)hash {
    if (_objectSchema.primaryKeyProperty) {
        // If we have a primary key property, that's an immutable value which we
        // can use as the identity of the object.
        id primaryProperty = [self valueForKey:_objectSchema.primaryKeyProperty.name];

        // modify the hash of our primary key value to avoid potential (although unlikely) collisions
        return [primaryProperty hash] ^ 1;
    }
    else if (_realm.isFrozen) {
        // The object key can never change for frozen objects, so that's usable
        // for objects without primary keys
        return static_cast<NSUInteger>(_row.get_key().value);
    }
    else {
        // Non-frozen objects without primary keys don't have any immutable
        // concept of identity that we can hash so we have to fall back to
        // pointer equality
        return [super hash];
    }
}

+ (BOOL)shouldIncludeInDefaultSchema {
    return LEGACYIsObjectSubclass(self);
}

+ (NSString *)primaryKey {
    return nil;
}

+ (NSString *)_realmObjectName {
    return nil;
}

+ (NSDictionary *)_realmColumnNames {
    return nil;
}

+ (bool)_realmIgnoreClass {
    return false;
}

+ (bool)isEmbedded {
    return false;
}

+ (bool)isAsymmetric {
    return false;
}

// This enables to override the propertiesMapping in Swift, it is not to be used in Objective-C API.
+ (NSDictionary *)propertiesMapping {
    return @{};
}

- (id)mutableArrayValueForKey:(NSString *)key {
    id obj = [self valueForKey:key];
    if ([obj isKindOfClass:[LEGACYArray class]]) {
        return obj;
    }
    return [super mutableArrayValueForKey:key];
}

- (id)mutableSetValueForKey:(NSString *)key {
    id obj = [self valueForKey:key];
    if ([obj isKindOfClass:[LEGACYSet class]]) {
        return obj;
    }
    return [super mutableSetValueForKey:key];
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    if (!_observationInfo) {
        _observationInfo = new LEGACYObservationInfo(self);
    }
    _observationInfo->recordObserver(_row, _info, _objectSchema, keyPath);

    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    [super removeObserver:observer forKeyPath:keyPath];
    if (_observationInfo)
        _observationInfo->removeObserver();
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    LEGACYProperty *prop = [self.class sharedSchema][key];
    if (isManagedAccessorClass(self)) {
        // Managed accessors explicitly call willChange/didChange for managed
        // properties, so we don't want KVO to override the setters to do that
        return !prop;
    }
    if (prop.swiftAccessor) {
        // Properties with swift accessors don't have obj-c getters/setters and
        // will explode if KVO tries to override them
        return NO;
    }

    return [super automaticallyNotifiesObserversForKey:key];
}

+ (void)observe:(LEGACYObjectBase *)object
       keyPaths:(nullable NSArray<NSString *> *)keyPaths
          block:(LEGACYObjectNotificationCallback)block
     completion:(void (^)(LEGACYNotificationToken *))completion {
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return realm::Object(_realm->_realm, *_info->objectSchema, _row);
}

- (id)objectiveCMetadata {
    return nil;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(__unused id)metadata
                                        realm:(LEGACYRealm *)realm {
    auto object = reference.resolve<realm::Object>(realm->_realm);
    if (!object.is_valid()) {
        return nil;
    }
    NSString *objectClassName = @(object.get_object_schema().name.c_str());
    return LEGACYCreateObjectAccessor(realm->_info[objectClassName], object.get_obj());
}

@end

LEGACYRealm *LEGACYObjectBaseRealm(__unsafe_unretained LEGACYObjectBase *object) {
    return object ? object->_realm : nil;
}

LEGACYObjectSchema *LEGACYObjectBaseObjectSchema(__unsafe_unretained LEGACYObjectBase *object) {
    return object ? object->_objectSchema : nil;
}

id LEGACYObjectBaseObjectForKeyedSubscript(LEGACYObjectBase *object, NSString *key) {
    if (!object) {
        return nil;
    }

    if (object->_realm) {
        return LEGACYDynamicGetByName(object, key);
    }
    else {
        return [object valueForKey:key];
    }
}

void LEGACYObjectBaseSetObjectForKeyedSubscript(LEGACYObjectBase *object, NSString *key, id obj) {
    if (!object) {
        return;
    }

    if (object->_realm || object.class == object->_objectSchema.accessorClass) {
        LEGACYDynamicValidatedSet(object, key, obj);
    }
    else {
        [object setValue:obj forKey:key];
    }
}


BOOL LEGACYObjectBaseAreEqual(LEGACYObjectBase *o1, LEGACYObjectBase *o2) {
    // if not the correct types throw
    if ((o1 && ![o1 isKindOfClass:LEGACYObjectBase.class]) || (o2 && ![o2 isKindOfClass:LEGACYObjectBase.class])) {
        @throw LEGACYException(@"Can only compare objects of class LEGACYObjectBase");
    }
    // if identical object (or both are nil)
    if (o1 == o2) {
        return YES;
    }
    // if one is nil
    if (o1 == nil || o2 == nil) {
        return NO;
    }
    // if not in realm or differing realms
    if (o1->_realm == nil || o1->_realm != o2->_realm) {
        return NO;
    }
    // if either are detached
    if (!o1->_row.is_valid() || !o2->_row.is_valid()) {
        return NO;
    }
    // if table and index are the same
    return o1->_row.get_table() == o2->_row.get_table()
        && o1->_row.get_key() == o2->_row.get_key();
}

static id resolveObject(LEGACYObjectBase *obj, LEGACYRealm *realm) {
    LEGACYObjectBase *resolved = LEGACYCreateManagedAccessor(obj.class, &realm->_info[obj->_info->rlmObjectSchema.className]);
    resolved->_row = realm->_realm->import_copy_of(obj->_row);
    if (!resolved->_row.is_valid()) {
        return nil;
    }
    LEGACYInitializeSwiftAccessor(resolved, false);
    return resolved;
}

id LEGACYObjectFreeze(LEGACYObjectBase *obj) {
    if (!obj->_realm && !obj.isInvalidated) {
        @throw LEGACYException(@"Unmanaged objects cannot be frozen.");
    }
    LEGACYVerifyAttached(obj);
    if (obj->_realm.frozen) {
        return obj;
    }
    obj = resolveObject(obj, obj->_realm.freeze);
    if (!obj) {
        @throw LEGACYException(@"Cannot freeze an object in the same write transaction as it was created in.");
    }
    return obj;
}

id LEGACYObjectThaw(LEGACYObjectBase *obj) {
    if (!obj->_realm && !obj.isInvalidated) {
        @throw LEGACYException(@"Unmanaged objects cannot be frozen.");
    }
    LEGACYVerifyAttached(obj);
    if (!obj->_realm.frozen) {
        return obj;
    }
    return resolveObject(obj, obj->_realm.thaw);
}

id LEGACYValidatedValueForProperty(id object, NSString *key, NSString *className) {
    @try {
        return [object valueForKey:key];
    }
    @catch (NSException *e) {
        if ([e.name isEqualToString:NSUndefinedKeyException]) {
            @throw LEGACYException(@"Invalid value '%@' to initialize object of type '%@': missing key '%@'",
                                object, className, key);
        }
        @throw;
    }
}

#pragma mark - Notifications

namespace {
struct ObjectChangeCallbackWrapper {
    LEGACYObjectNotificationCallback block;
    LEGACYObjectBase *object;
    void (^registrationCompletion)();

    NSArray<NSString *> *propertyNames = nil;
    NSArray *oldValues = nil;
    bool deleted = false;

    void populateProperties(realm::CollectionChangeSet const& c) {
        if (propertyNames) {
            return;
        }
        if (!c.deletions.empty()) {
            deleted = true;
            return;
        }
        if (c.columns.empty()) {
            return;
        }

        // FIXME: It's possible for the column key of a persisted property
        // to equal the column key of a computed property.
        auto properties = [NSMutableArray new];
        for (LEGACYProperty *property in object->_info->rlmObjectSchema.properties) {
            auto columnKey = object->_info->tableColumn(property).value;
            if (c.columns.count(columnKey)) {
                [properties addObject:property.name];
            }
        }
        for (LEGACYProperty *property in object->_info->rlmObjectSchema.computedProperties) {
            auto columnKey = object->_info->computedTableColumn(property).value;
            if (c.columns.count(columnKey)) {
                [properties addObject:property.name];
            }
        }
        if (properties.count) {
            propertyNames = properties;
        }
    }

    NSArray *readValues(realm::CollectionChangeSet const& c) {
        if (c.empty()) {
            return nil;
        }
        populateProperties(c);
        if (!propertyNames) {
            return nil;
        }

        auto values = [NSMutableArray arrayWithCapacity:propertyNames.count];
        for (NSString *name in propertyNames) {
            id value = [object valueForKey:name];
            if (!value || [value isKindOfClass:[LEGACYArray class]]) {
                [values addObject:NSNull.null];
            }
            else {
                [values addObject:value];
            }
        }
        return values;
    }

    void before(realm::CollectionChangeSet const& c) {
        @autoreleasepool {
            oldValues = readValues(c);
        }
    }

    void after(realm::CollectionChangeSet const& c) {
        @autoreleasepool {
            if (registrationCompletion) {
                registrationCompletion();
                registrationCompletion = nil;
            }
            auto newValues = readValues(c);
            if (deleted) {
                block(nil, nil, nil, nil, nil);
            }
            else if (newValues) {
                block(object, propertyNames, oldValues, newValues, nil);
            }
            propertyNames = nil;
            oldValues = nil;
        }
    }
};
} // anonymous namespace

@interface LEGACYPropertyChange ()
@property (nonatomic, readwrite, strong) NSString *name;
@property (nonatomic, readwrite, strong, nullable) id previousValue;
@property (nonatomic, readwrite, strong, nullable) id value;
@end

@implementation LEGACYPropertyChange
- (NSString *)description {
    return [NSString stringWithFormat:@"<LEGACYPropertyChange: %p> %@ %@ -> %@",
            (__bridge void *)self, _name, _previousValue, _value];
}
@end

enum class TokenState {
    Initializing,
    Cancelled,
    Ready
};

LEGACY_DIRECT_MEMBERS
@implementation LEGACYObjectNotificationToken {
    LEGACYUnfairMutex _mutex;
    __unsafe_unretained LEGACYRealm *_realm;
    realm::Object _object;
    realm::NotificationToken _token;
    void (^_completion)(void);
    TokenState _state;
}

- (LEGACYRealm *)realm {
    std::lock_guard lock(_mutex);
    return _realm;
}

- (void)suppressNextNotification {
    std::lock_guard lock(_mutex);
    if (_object.is_valid()) {
        _token.suppress_next();
    }
}

- (bool)invalidate {
    dispatch_block_t completion;
    {
        std::lock_guard lock(_mutex);
        if (_state == TokenState::Cancelled) {
            REALM_ASSERT(!_completion);
            return false;
        }
        _realm = nil;
        _token = {};
        _object = {};
        _state = TokenState::Cancelled;
        std::swap(completion, _completion);
    }
    if (completion) {
        completion();
    }
    return true;
}

- (void)addNotificationBlock:(LEGACYObjectNotificationCallback)block
         threadSafeReference:(LEGACYThreadSafeReference *)tsr
                      config:(LEGACYRealmConfiguration *)config
                    keyPaths:(NSArray *)keyPaths
                       queue:(dispatch_queue_t)queue {
    std::lock_guard lock(_mutex);
    if (_state != TokenState::Initializing) {
        // Token was invalidated before we got this far
        return;
    }

    NSError *error;
    _realm = [LEGACYRealm realmWithConfiguration:config queue:queue error:&error];
    if (!_realm) {
        block(nil, nil, nil, nil, error);
        return;
    }
    LEGACYObjectBase *obj = [_realm resolveThreadSafeReference:tsr];

    _object = realm::Object(_realm->_realm, *obj->_info->objectSchema, obj->_row);
    _token = _object.add_notification_callback(ObjectChangeCallbackWrapper{block, obj},
                                               obj->_info->keyPathArrayFromStringArray(keyPaths));
}

- (void)observe:(LEGACYObjectBase *)obj
       keyPaths:(NSArray *)keyPaths
          block:(LEGACYObjectNotificationCallback)block {
    std::lock_guard lock(_mutex);
    if (_state != TokenState::Initializing) {
        return;
    }
    _object = realm::Object(obj->_realm->_realm, *obj->_info->objectSchema, obj->_row);
    _realm = obj->_realm;

    auto completion = [self] {
        dispatch_block_t completion;
        {
            std::lock_guard lock(_mutex);
            if (_state == TokenState::Initializing) {
                _state = TokenState::Ready;
            }
            std::swap(completion, _completion);
        }
        if (completion) {
            completion();
        }
    };
    try {
        _token = _object.add_notification_callback(ObjectChangeCallbackWrapper{block, obj, completion},
                                                   obj->_info->keyPathArrayFromStringArray(keyPaths));
    }
    catch (const realm::Exception& e) {
        @throw LEGACYException(e);
    }
}

- (void)registrationComplete:(void (^)())completion {
    {
        std::lock_guard lock(_mutex);
        if (_state == TokenState::Initializing) {
            _completion = completion;
            return;
        }
    }
    completion();
}

LEGACYNotificationToken *LEGACYObjectBaseAddNotificationBlock(LEGACYObjectBase *obj,
                                                        NSArray<NSString *> *keyPaths,
                                                        dispatch_queue_t queue,
                                                        LEGACYObjectNotificationCallback block) {
    if (!obj->_realm) {
        @throw LEGACYException(@"Only objects which are managed by a Realm support change notifications");
    }

    if (!queue) {
        [obj->_realm verifyNotificationsAreSupported:true];
        auto token = [[LEGACYObjectNotificationToken alloc] init];
        [token observe:obj keyPaths:keyPaths block:block];
        return token;
    }

    LEGACYThreadSafeReference *tsr = [LEGACYThreadSafeReference referenceWithThreadConfined:(id)obj];
    auto token = [[LEGACYObjectNotificationToken alloc] init];
    token->_realm = obj->_realm;
    LEGACYRealmConfiguration *config = obj->_realm.configuration;
    dispatch_async(queue, ^{
        @autoreleasepool {
            [token addNotificationBlock:block threadSafeReference:tsr config:config keyPaths:keyPaths queue:queue];
        }
    });
    return token;
}
@end

LEGACYNotificationToken *LEGACYObjectAddNotificationBlock(LEGACYObjectBase *obj, LEGACYObjectChangeBlock block, NSArray<NSString *> *keyPaths, dispatch_queue_t queue) {
    return LEGACYObjectBaseAddNotificationBlock(obj, keyPaths, queue, ^(LEGACYObjectBase *, NSArray<NSString *> *propertyNames,
                                                           NSArray *oldValues, NSArray *newValues, NSError *error) {
        if (error) {
            block(false, nil, error);
        }
        else if (!propertyNames) {
            block(true, nil, nil);
        }
        else {
            auto properties = [NSMutableArray arrayWithCapacity:propertyNames.count];
            for (NSUInteger i = 0, count = propertyNames.count; i < count; ++i) {
                auto prop = [LEGACYPropertyChange new];
                prop.name = propertyNames[i];
                prop.previousValue = LEGACYCoerceToNil(oldValues[i]);
                prop.value = LEGACYCoerceToNil(newValues[i]);
                [properties addObject:prop];
            }
            block(false, properties, nil);
        }
    });
}

uint64_t LEGACYObjectBaseGetCombineId(__unsafe_unretained LEGACYObjectBase *const obj) {
    if (obj.invalidated) {
        LEGACYVerifyAttached(obj);
    }
    if (obj->_realm) {
        return obj->_row.get_key().value;
    }
    return reinterpret_cast<uint64_t>((__bridge void *)obj);
}

@implementation RealmSwiftLegacyObject
+ (BOOL)accessInstanceVariablesDirectly {
    // By default KVO will try to directly read ivars if a thing with a matching
    // name is observed and there's no objc property with that name. This
    // crashes when it tries to read a property wrapper ivar, and is never
    // useful for Swift classes.
    return NO;
}
@end

@implementation RealmSwiftLegacyEmbeddedObject
+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}
@end

@implementation RealmSwiftLegacyAsymmetricObject
+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

+ (bool)isAsymmetric {
    return YES;
}
@end
