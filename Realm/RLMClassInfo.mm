////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import "LEGACYClassInfo.hpp"

#import "LEGACYRealm_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYSchema.h"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/object_schema.hpp>
#import <realm/object-store/object_store.hpp>
#import <realm/object-store/schema.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/table.hpp>

using namespace realm;

LEGACYClassInfo::LEGACYClassInfo(__unsafe_unretained LEGACYRealm *const realm,
                           __unsafe_unretained LEGACYObjectSchema *const rlmObjectSchema,
                           const realm::ObjectSchema *objectSchema)
: realm(realm), rlmObjectSchema(rlmObjectSchema), objectSchema(objectSchema) { }

LEGACYClassInfo::LEGACYClassInfo(LEGACYRealm *realm, LEGACYObjectSchema *rlmObjectSchema,
                           std::unique_ptr<realm::ObjectSchema> schema)
: realm(realm)
, rlmObjectSchema(rlmObjectSchema)
, objectSchema(&*schema)
, dynamicObjectSchema(std::move(schema))
, dynamicLEGACYObjectSchema(rlmObjectSchema)
{ }

realm::TableRef LEGACYClassInfo::table() const {
    if (auto key = objectSchema->table_key) {
        return realm.group.get_table(objectSchema->table_key);
    }
    return nullptr;
}

LEGACYProperty *LEGACYClassInfo::propertyForTableColumn(ColKey col) const noexcept {
    auto const& props = objectSchema->persisted_properties;
    for (size_t i = 0; i < props.size(); ++i) {
        if (props[i].column_key == col) {
            return rlmObjectSchema.properties[i];
        }
    }
    return nil;
}

LEGACYProperty *LEGACYClassInfo::propertyForPrimaryKey() const noexcept {
    return rlmObjectSchema.primaryKeyProperty;
}

realm::ColKey LEGACYClassInfo::tableColumn(NSString *propertyName) const {
    return tableColumn(LEGACYValidatedProperty(rlmObjectSchema, propertyName));
}

realm::ColKey LEGACYClassInfo::tableColumn(LEGACYProperty *property) const {
    return objectSchema->persisted_properties[property.index].column_key;
}

realm::ColKey LEGACYClassInfo::computedTableColumn(LEGACYProperty *property) const {
    // Retrieve the table key and class info for the origin property
    // that corresponds to the target property.
    LEGACYClassInfo& originInfo = realm->_info[property.objectClassName];
    TableKey originTableKey = originInfo.objectSchema->table_key;

    TableRef originTable = realm.group.get_table(originTableKey);
    // Get the column key for origin's forward link that links to the property on the target.
    ColKey forwardLinkKey = originInfo.tableColumn(property.linkOriginPropertyName);

    // The column key opposite of the origin's forward link is the target's backlink property.
    return originTable->get_opposite_column(forwardLinkKey);
}

LEGACYClassInfo &LEGACYClassInfo::linkTargetType(size_t propertyIndex) {
    return realm->_info[rlmObjectSchema.properties[propertyIndex].objectClassName];
}

LEGACYClassInfo &LEGACYClassInfo::linkTargetType(realm::Property const& property) {
    REALM_ASSERT(property.type == PropertyType::Object);
    return linkTargetType(&property - &objectSchema->persisted_properties[0]);
}

LEGACYClassInfo &LEGACYClassInfo::resolve(__unsafe_unretained LEGACYRealm *const realm) {
    return realm->_info[rlmObjectSchema.className];
}

bool LEGACYClassInfo::isSwiftClass() const noexcept {
    return rlmObjectSchema.isSwiftClass;
}

bool LEGACYClassInfo::isDynamic() const noexcept {
    return !!dynamicObjectSchema;
}

static KeyPath keyPathFromString(LEGACYRealm *realm,
                                 LEGACYSchema *schema,
                                 const LEGACYClassInfo *info,
                                 LEGACYObjectSchema *rlmObjectSchema,
                                 NSString *keyPath) {
    KeyPath keyPairs;

    for (NSString *component in [keyPath componentsSeparatedByString:@"."]) {
        LEGACYProperty *property = rlmObjectSchema[component];
        if (!property) {
            throw LEGACYException(@"Invalid property name: property '%@' not found in object of type '%@'",
                               component, rlmObjectSchema.className);
        }

        TableKey tk = info->objectSchema->table_key;
        ColKey ck;
        if (property.type == LEGACYPropertyTypeObject) {
            ck = info->tableColumn(property.name);
            info = &realm->_info[property.objectClassName];
            rlmObjectSchema = schema[property.objectClassName];
        } else if (property.type == LEGACYPropertyTypeLinkingObjects) {
            ck = info->computedTableColumn(property);
            info = &realm->_info[property.objectClassName];
            rlmObjectSchema = schema[property.objectClassName];
        } else {
            ck = info->tableColumn(property.name);
        }

        keyPairs.emplace_back(tk, ck);
    }
    return keyPairs;
}

std::optional<realm::KeyPathArray> LEGACYClassInfo::keyPathArrayFromStringArray(NSArray<NSString *> *keyPaths) const {
    std::optional<KeyPathArray> keyPathArray;
    if (keyPaths.count) {
        keyPathArray.emplace();
        for (NSString *keyPath in keyPaths) {
            keyPathArray->push_back(keyPathFromString(realm, realm.schema, this,
                                                      rlmObjectSchema, keyPath));
        }
    }
    return keyPathArray;
}

LEGACYSchemaInfo::impl::iterator LEGACYSchemaInfo::begin() noexcept { return m_objects.begin(); }
LEGACYSchemaInfo::impl::iterator LEGACYSchemaInfo::end() noexcept { return m_objects.end(); }
LEGACYSchemaInfo::impl::const_iterator LEGACYSchemaInfo::begin() const noexcept { return m_objects.begin(); }
LEGACYSchemaInfo::impl::const_iterator LEGACYSchemaInfo::end() const noexcept { return m_objects.end(); }

LEGACYClassInfo& LEGACYSchemaInfo::operator[](NSString *name) {
    auto it = m_objects.find(name);
    if (it == m_objects.end()) {
        @throw LEGACYException(@"Object type '%@' is not managed by the Realm. "
                            @"If using a custom `objectClasses` / `objectTypes` array in your configuration, "
                            @"add `%@` to the list of `objectClasses` / `objectTypes`.",
                            name, name);
    }
    return *&it->second;
}

LEGACYClassInfo* LEGACYSchemaInfo::operator[](realm::TableKey key) {
    for (auto& [name, info] : m_objects) {
        if (info.objectSchema->table_key == key)
            return &info;
    }
    return nullptr;
}

LEGACYSchemaInfo::LEGACYSchemaInfo(LEGACYRealm *realm) {
    LEGACYSchema *rlmSchema = realm.schema;
    realm::Schema const& schema = realm->_realm->schema();
    // rlmSchema can be larger due to multiple classes backed by one table
    REALM_ASSERT(rlmSchema.objectSchema.count >= schema.size());

    m_objects.reserve(schema.size());
    for (LEGACYObjectSchema *rlmObjectSchema in rlmSchema.objectSchema) {
        auto it = schema.find(rlmObjectSchema.objectStoreName);
        if (it == schema.end()) {
            continue;
        }
        m_objects.emplace(std::piecewise_construct,
                          std::forward_as_tuple(rlmObjectSchema.className),
                          std::forward_as_tuple(realm, rlmObjectSchema,
                                                &*it));
    }
}

LEGACYSchemaInfo LEGACYSchemaInfo::clone(realm::Schema const& source_schema,
                                   __unsafe_unretained LEGACYRealm *const target_realm) {
    LEGACYSchemaInfo info;
    info.m_objects.reserve(m_objects.size());

    auto& schema = target_realm->_realm->schema();
    REALM_ASSERT_DEBUG(schema == source_schema);
    for (auto& [name, class_info] : m_objects) {
        if (class_info.isDynamic()) {
            continue;
        }
        size_t idx = class_info.objectSchema - &*source_schema.begin();
        info.m_objects.emplace(std::piecewise_construct,
                               std::forward_as_tuple(name),
                               std::forward_as_tuple(target_realm, class_info.rlmObjectSchema,
                                                     &*schema.begin() + idx));
    }
    return info;
}

void LEGACYSchemaInfo::appendDynamicObjectSchema(std::unique_ptr<realm::ObjectSchema> schema,
                                              LEGACYObjectSchema *objectSchema,
                                              __unsafe_unretained LEGACYRealm *const target_realm) {
    m_objects.emplace(std::piecewise_construct,
                      std::forward_as_tuple(objectSchema.className),
                      std::forward_as_tuple(target_realm, objectSchema,
                                            std::move(schema)));
}
