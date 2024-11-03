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

#import "LEGACYObjectSchema_Private.hpp"

#import "LEGACYEmbeddedObject.h"
#import "LEGACYObject_Private.h"
#import "LEGACYProperty_Private.hpp"
#import "LEGACYRealm_Dynamic.h"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYSchema_Private.h"
#import "LEGACYSwiftCollectionBase.h"
#import "LEGACYSwiftSupport.h"
#import "LEGACYUtil.hpp"

#import <realm/object-store/object_schema.hpp>
#import <realm/object-store/object_store.hpp>

using namespace realm;

@protocol LEGACYCustomEventRepresentable
@end

// private properties
@interface LEGACYObjectSchema ()
@property (nonatomic, readwrite) NSDictionary<id, LEGACYProperty *> *allPropertiesByName;
@property (nonatomic, readwrite) NSString *className;
@end

@implementation LEGACYObjectSchema {
    std::string _objectStoreName;
}

- (instancetype)initWithClassName:(NSString *)objectClassName objectClass:(Class)objectClass properties:(NSArray *)properties {
    self = [super init];
    self.className = objectClassName;
    self.properties = properties;
    self.objectClass = objectClass;
    self.accessorClass = objectClass;
    self.unmanagedClass = objectClass;
    return self;
}

// return properties by name
- (LEGACYProperty *)objectForKeyedSubscript:(__unsafe_unretained NSString *const)key {
    return _allPropertiesByName[key];
}

// create property map when setting property array
- (void)setProperties:(NSArray *)properties {
    _properties = properties;
    [self _propertiesDidChange];
}

- (void)setComputedProperties:(NSArray *)computedProperties {
    _computedProperties = computedProperties;
    [self _propertiesDidChange];
}

- (void)_propertiesDidChange {
    _primaryKeyProperty = nil;
    NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:_properties.count + _computedProperties.count];
    NSUInteger index = 0;
    for (LEGACYProperty *prop in _properties) {
        prop.index = index++;
        map[prop.name] = prop;
        if (prop.isPrimary) {
            if (_primaryKeyProperty) {
                @throw LEGACYException(@"Properties '%@' and '%@' are both marked as the primary key of '%@'",
                                    prop.name, _primaryKeyProperty.name, _className);
            }
            _primaryKeyProperty = prop;
        }
    }
    index = 0;
    for (LEGACYProperty *prop in _computedProperties) {
        prop.index = index++;
        map[prop.name] = prop;
    }
    _allPropertiesByName = map;

    if (LEGACYIsSwiftObjectClass(_accessorClass)) {
        NSMutableArray *genericProperties = [NSMutableArray new];
        for (LEGACYProperty *prop in _properties) {
            if (prop.swiftAccessor) {
                [genericProperties addObject:prop];
            }
        }
        // Currently all computed properties are Swift generics
        [genericProperties addObjectsFromArray:_computedProperties];

        if (genericProperties.count) {
            _swiftGenericProperties = genericProperties;
        }
        else {
            _swiftGenericProperties = nil;
        }
    }
}


- (void)setPrimaryKeyProperty:(LEGACYProperty *)primaryKeyProperty {
    _primaryKeyProperty.isPrimary = NO;
    primaryKeyProperty.isPrimary = YES;
    _primaryKeyProperty = primaryKeyProperty;
    _primaryKeyProperty.indexed = YES;
}

+ (instancetype)schemaForObjectClass:(Class)objectClass {
    LEGACYObjectSchema *schema = [LEGACYObjectSchema new];

    // determine classname from objectclass as className method has not yet been updated
    NSString *className = NSStringFromClass(objectClass);
    bool hasSwiftName = [LEGACYSwiftSupport isSwiftClassName:className];
    if (hasSwiftName) {
        className = [LEGACYSwiftSupport demangleClassName:className];
    }

    bool isSwift = hasSwiftName || LEGACYIsSwiftObjectClass(objectClass);

    schema.className = className;
    schema.objectClass = objectClass;
    schema.accessorClass = objectClass;
    schema.unmanagedClass = objectClass;
    schema.isSwiftClass = isSwift;
    schema.hasCustomEventSerialization = [objectClass conformsToProtocol:@protocol(LEGACYCustomEventRepresentable)];

    bool isEmbedded = [(id)objectClass isEmbedded];
    bool isAsymmetric = [(id)objectClass isAsymmetric];
    REALM_ASSERT(!(isEmbedded && isAsymmetric));
    schema.isEmbedded = isEmbedded;
    schema.isAsymmetric = isAsymmetric;

    // create array of LEGACYProperties, inserting properties of superclasses first
    Class cls = objectClass;
    Class superClass = class_getSuperclass(cls);
    NSArray *allProperties = @[];
    while (superClass && superClass != LEGACYObjectBase.class) {
        allProperties = [[LEGACYObjectSchema propertiesForClass:cls isSwift:isSwift]
                         arrayByAddingObjectsFromArray:allProperties];
        cls = superClass;
        superClass = class_getSuperclass(superClass);
    }
    NSArray *persistedProperties = [allProperties filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LEGACYProperty *property, NSDictionary *) {
        return !LEGACYPropertyTypeIsComputed(property.type);
    }]];
    schema.properties = persistedProperties;

    NSArray *computedProperties = [allProperties filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LEGACYProperty *property, NSDictionary *) {
        return LEGACYPropertyTypeIsComputed(property.type);
    }]];
    schema.computedProperties = computedProperties;

    // verify that we didn't add any properties twice due to inheritance
    if (allProperties.count != [NSSet setWithArray:[allProperties valueForKey:@"name"]].count) {
        NSCountedSet *countedPropertyNames = [NSCountedSet setWithArray:[allProperties valueForKey:@"name"]];
        NSArray *duplicatePropertyNames = [countedPropertyNames filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *) {
            return [countedPropertyNames countForObject:object] > 1;
        }]].allObjects;

        if (duplicatePropertyNames.count == 1) {
            @throw LEGACYException(@"Property '%@' is declared multiple times in the class hierarchy of '%@'", duplicatePropertyNames.firstObject, className);
        } else {
            @throw LEGACYException(@"Object '%@' has properties that are declared multiple times in its class hierarchy: '%@'", className, [duplicatePropertyNames componentsJoinedByString:@"', '"]);
        }
    }

    if (NSString *primaryKey = [objectClass primaryKey]) {
        for (LEGACYProperty *prop in schema.properties) {
            if ([primaryKey isEqualToString:prop.name]) {
                prop.indexed = YES;
                schema.primaryKeyProperty = prop;
                break;
            }
        }

        if (!schema.primaryKeyProperty) {
            @throw LEGACYException(@"Primary key property '%@' does not exist on object '%@'", primaryKey, className);
        }
        if (schema.primaryKeyProperty.type != LEGACYPropertyTypeInt &&
            schema.primaryKeyProperty.type != LEGACYPropertyTypeString &&
            schema.primaryKeyProperty.type != LEGACYPropertyTypeObjectId &&
            schema.primaryKeyProperty.type != LEGACYPropertyTypeUUID) {
            @throw LEGACYException(@"Property '%@' cannot be made the primary key of '%@' because it is not a 'string', 'int', 'objectId', or 'uuid' property.",
                                primaryKey, className);
        }
    }

    for (LEGACYProperty *prop in schema.properties) {
        if (prop.optional && prop.collection && !prop.dictionary && (prop.type == LEGACYPropertyTypeObject || prop.type == LEGACYPropertyTypeLinkingObjects)) {
            // FIXME: message is awkward
            @throw LEGACYException(@"Property '%@.%@' cannot be made optional because optional '%@' properties are not supported.",
                                className, prop.name, LEGACYTypeToString(prop.type));
        }
    }

    if ([objectClass shouldIncludeInDefaultSchema]
        && schema.isSwiftClass
        && schema.properties.count == 0
        && schema.computedProperties.count == 0) {
        @throw LEGACYException(@"No properties are defined for '%@'. Did you remember to mark them with '@objc' or '@Persisted' in your model?", schema.className);
    }
    return schema;
}

+ (NSArray *)propertiesForClass:(Class)objectClass isSwift:(bool)isSwiftClass {
    if (NSArray<LEGACYProperty *> *props = [objectClass _getProperties]) {
        return props;
    }

    // For Swift subclasses of LEGACYObject we need an instance of the object when parsing properties
    id swiftObjectInstance = isSwiftClass ? [[objectClass alloc] init] : nil;

    NSArray *ignoredProperties = [objectClass ignoredProperties];
    NSDictionary *linkingObjectsProperties = [objectClass linkingObjectsProperties];
    NSDictionary *columnNameMap = [objectClass _realmColumnNames];

    unsigned int count;
    std::unique_ptr<objc_property_t[], decltype(&free)> props(class_copyPropertyList(objectClass, &count), &free);
    NSMutableArray<LEGACYProperty *> *propArray = [NSMutableArray arrayWithCapacity:count];
    NSSet *indexed = [[NSSet alloc] initWithArray:[objectClass indexedProperties]];
    for (unsigned int i = 0; i < count; i++) {
        NSString *propertyName = @(property_getName(props[i]));
        if ([ignoredProperties containsObject:propertyName]) {
            continue;
        }

        LEGACYProperty *prop = nil;
        if (isSwiftClass) {
            prop = [[LEGACYProperty alloc] initSwiftPropertyWithName:propertyName
                                                          indexed:[indexed containsObject:propertyName]
                                           linkPropertyDescriptor:linkingObjectsProperties[propertyName]
                                                         property:props[i]
                                                         instance:swiftObjectInstance];
        }
        else {
            prop = [[LEGACYProperty alloc] initWithName:propertyName
                                             indexed:[indexed containsObject:propertyName]
                              linkPropertyDescriptor:linkingObjectsProperties[propertyName]
                                            property:props[i]];
        }

        if (prop) {
            if (columnNameMap) {
                prop.columnName = columnNameMap[prop.name];
            }
            [propArray addObject:prop];
        }
    }

    if (auto requiredProperties = [objectClass requiredProperties]) {
        for (LEGACYProperty *property in propArray) {
            bool required = [requiredProperties containsObject:property.name];
            if (required && property.type == LEGACYPropertyTypeObject && (!property.collection || property.dictionary)) {
                @throw LEGACYException(@"Object properties cannot be made required, "
                                    "but '+[%@ requiredProperties]' included '%@'", objectClass, property.name);
            }
            property.optional &= !required;
        }
    }

    for (LEGACYProperty *property in propArray) {
        if (!property.optional && property.type == LEGACYPropertyTypeObject && !property.collection) {
            @throw LEGACYException(@"The `%@.%@` property must be marked as being optional.",
                                [objectClass className], property.name);
        }
        if (property.type == LEGACYPropertyTypeAny) {
            property.optional = NO;
        }
    }

    return propArray;
}

- (id)copyWithZone:(NSZone *)zone {
    LEGACYObjectSchema *schema = [[LEGACYObjectSchema allocWithZone:zone] init];
    schema->_objectClass = _objectClass;
    schema->_className = _className;
    schema->_objectClass = _objectClass;
    schema->_accessorClass = _objectClass;
    schema->_unmanagedClass = _unmanagedClass;
    schema->_isSwiftClass = _isSwiftClass;
    schema->_isEmbedded = _isEmbedded;
    schema->_isAsymmetric = _isAsymmetric;
    schema->_properties = [[NSArray allocWithZone:zone] initWithArray:_properties copyItems:YES];
    schema->_computedProperties = [[NSArray allocWithZone:zone] initWithArray:_computedProperties copyItems:YES];
    [schema _propertiesDidChange];
    return schema;
}

- (BOOL)isEqualToObjectSchema:(LEGACYObjectSchema *)objectSchema {
    if (objectSchema.properties.count != _properties.count) {
        return NO;
    }

    if (![_properties isEqualToArray:objectSchema.properties]) {
        return NO;
    }
    if (![_computedProperties isEqualToArray:objectSchema.computedProperties]) {
        return NO;
    }

    return YES;
}

- (NSString *)description {
    NSMutableString *propertiesString = [NSMutableString string];
    for (LEGACYProperty *property in self.properties) {
        [propertiesString appendFormat:@"\t%@\n", [property.description stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    }
    for (LEGACYProperty *property in self.computedProperties) {
        [propertiesString appendFormat:@"\t%@\n", [property.description stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    }
    return [NSString stringWithFormat:@"%@ %@{\n%@}",
            self.className, _isEmbedded ? @"(embedded) " : @"", propertiesString];
}

- (NSString *)objectName {
    return [self.objectClass _realmObjectName] ?: _className;
}

- (std::string const&)objectStoreName {
    if (_objectStoreName.empty()) {
        _objectStoreName = self.objectName.UTF8String;
    }
    return _objectStoreName;
}

- (realm::ObjectSchema)objectStoreCopy:(LEGACYSchema *)schema {
    using Type = ObjectSchema::ObjectType;
    ObjectSchema objectSchema;
    objectSchema.name = self.objectStoreName;
    objectSchema.primary_key = _primaryKeyProperty ? _primaryKeyProperty.columnName.UTF8String : "";
    objectSchema.table_type = _isAsymmetric ? Type::TopLevelAsymmetric : _isEmbedded ? Type::Embedded : Type::TopLevel;
    for (LEGACYProperty *prop in _properties) {
        Property p = [prop objectStoreCopy:schema];
        p.is_primary = (prop == _primaryKeyProperty);
        objectSchema.persisted_properties.push_back(std::move(p));
    }
    for (LEGACYProperty *prop in _computedProperties) {
        objectSchema.computed_properties.push_back([prop objectStoreCopy:schema]);
    }
    return objectSchema;
}

+ (instancetype)objectSchemaForObjectStoreSchema:(realm::ObjectSchema const&)objectSchema {
    LEGACYObjectSchema *schema = [LEGACYObjectSchema new];
    schema.className = @(objectSchema.name.c_str());
    schema.isEmbedded = objectSchema.table_type == ObjectSchema::ObjectType::Embedded;
    schema.isAsymmetric = objectSchema.table_type == ObjectSchema::ObjectType::TopLevelAsymmetric;

    // create array of LEGACYProperties
    NSMutableArray *properties = [NSMutableArray arrayWithCapacity:objectSchema.persisted_properties.size()];
    for (const Property &prop : objectSchema.persisted_properties) {
        LEGACYProperty *property = [LEGACYProperty propertyForObjectStoreProperty:prop];
        property.isPrimary = (prop.name == objectSchema.primary_key);
        [properties addObject:property];
    }
    schema.properties = properties;

    NSMutableArray *computedProperties = [NSMutableArray arrayWithCapacity:objectSchema.computed_properties.size()];
    for (const Property &prop : objectSchema.computed_properties) {
        [computedProperties addObject:[LEGACYProperty propertyForObjectStoreProperty:prop]];
    }
    schema.computedProperties = computedProperties;

    // get primary key from realm metadata
    if (objectSchema.primary_key.length()) {
        NSString *primaryKeyString = [NSString stringWithUTF8String:objectSchema.primary_key.c_str()];
        schema.primaryKeyProperty = schema[primaryKeyString];
        if (!schema.primaryKeyProperty) {
            @throw LEGACYException(@"No property matching primary key '%@'", primaryKeyString);
        }
    }

    // for dynamic schema use vanilla LEGACYDynamicObject accessor classes
    schema.objectClass = LEGACYObject.class;
    schema.accessorClass = LEGACYDynamicObject.class;
    schema.unmanagedClass = LEGACYObject.class;

    return schema;
}

@end
