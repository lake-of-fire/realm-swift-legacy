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

#import <Realm/LEGACYConstants.h>

#import <realm/table_ref.hpp>
#import <realm/util/optional.hpp>

#import <unordered_map>
#import <vector>

namespace realm {
    class ObjectSchema;
    class Schema;
    struct Property;
    struct ColKey;
    struct TableKey;
}

class LEGACYObservationInfo;
@class LEGACYRealm, LEGACYSchema, LEGACYObjectSchema, LEGACYProperty;

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

namespace std {
// Add specializations so that NSString can be used as the key for hash containers
template<> struct hash<NSString *> {
    size_t operator()(__unsafe_unretained NSString *const str) const {
        return [str hash];
    }
};
template<> struct equal_to<NSString *> {
    bool operator()(__unsafe_unretained NSString * lhs, __unsafe_unretained NSString *rhs) const {
        return [lhs isEqualToString:rhs];
    }
};
}

// The per-LEGACYRealm object schema information which stores the cached table
// reference, handles table column lookups, and tracks observed objects
class LEGACYClassInfo {
public:
    LEGACYClassInfo(LEGACYRealm *, LEGACYObjectSchema *, const realm::ObjectSchema *);

    LEGACYClassInfo(LEGACYRealm *realm, LEGACYObjectSchema *rlmObjectSchema,
                 std::unique_ptr<realm::ObjectSchema> objectSchema);

    __unsafe_unretained LEGACYRealm *const realm;
    __unsafe_unretained LEGACYObjectSchema *const rlmObjectSchema;
    const realm::ObjectSchema *const objectSchema;

    // Storage for the functionality in LEGACYObservation for handling indirect
    // changes to KVO-observed things
    std::vector<LEGACYObservationInfo *> observedObjects;

    // Get the table for this object type. Will return nullptr only if it's a
    // read-only Realm that is missing the table entirely.
    realm::TableRef table() const;

    // Get the LEGACYProperty for a given table column, or `nil` if it is a column
    // not used by the current schema
    LEGACYProperty *_Nullable propertyForTableColumn(realm::ColKey) const noexcept;

    // Get the LEGACYProperty that's used as the primary key, or `nil` if there is
    // no primary key for the current schema
    LEGACYProperty *_Nullable propertyForPrimaryKey() const noexcept;

    // Get the table column for the given property. The property must be a valid
    // persisted property.
    realm::ColKey tableColumn(NSString *propertyName) const;
    realm::ColKey tableColumn(LEGACYProperty *property) const;
    // Get the table column key for the given computed property. The property
    // must be a valid computed property.
    // Subscripting a `realm::ObjectSchema->computed_properties[property.index]`
    // does not return a valid colKey, unlike subscripting persisted_properties.
    // This method retrieves a valid column key for computed properties by
    // getting the opposite table column of the origin's "forward" link.
    realm::ColKey computedTableColumn(LEGACYProperty *property) const;

    // Get the info for the target of the link at the given property index.
    LEGACYClassInfo &linkTargetType(size_t propertyIndex);

    // Get the info for the target of the given property
    LEGACYClassInfo &linkTargetType(realm::Property const& property);

    // Get the corresponding ClassInfo for the given Realm
    LEGACYClassInfo &resolve(LEGACYRealm *);

    // Return true if the LEGACYObjectSchema is for a Swift class
    bool isSwiftClass() const noexcept;

    // Returns true if this was a dynamically added type
    bool isDynamic() const noexcept;

    // KeyPathFromString converts a string keypath to a vector of key
    // pairs to be used for deep change checking across links.
    // NEXT-MAJOR: This conflates a nil array and an empty array for backwards
    // compatibility, but core now gives them different semantics
    std::optional<std::vector<std::vector<std::pair<realm::TableKey, realm::ColKey>>>>
    keyPathArrayFromStringArray(NSArray<NSString *> *keyPaths) const;

private:
    // If the ObjectSchema is not owned by the realm instance
    // we need to manually manage the ownership of the object.
    std::unique_ptr<realm::ObjectSchema> dynamicObjectSchema;
    [[maybe_unused]] LEGACYObjectSchema *_Nullable dynamicLEGACYObjectSchema;
};

// A per-LEGACYRealm object schema map which stores LEGACYClassInfo keyed on the name
class LEGACYSchemaInfo {
    using impl = std::unordered_map<NSString *, LEGACYClassInfo>;

public:
    LEGACYSchemaInfo() = default;
    LEGACYSchemaInfo(LEGACYRealm *realm);

    LEGACYSchemaInfo clone(realm::Schema const& source_schema, LEGACYRealm *target_realm);

    // Look up by name, throwing if it's not present
    LEGACYClassInfo& operator[](NSString *name);
    // Look up by table key, return none if its not present.
    LEGACYClassInfo* operator[](realm::TableKey tableKey);

    // Emplaces a locally derived object schema into LEGACYSchemaInfo. This is used
    // when creating objects dynamically that are not registered in the Cocoa schema.
    // Note: `LEGACYClassInfo` assumes ownership of `schema`.
    void appendDynamicObjectSchema(std::unique_ptr<realm::ObjectSchema> schema,
                                   LEGACYObjectSchema *objectSchema,
                                   LEGACYRealm *const target_realm);

    impl::iterator begin() noexcept;
    impl::iterator end() noexcept;
    impl::const_iterator begin() const noexcept;
    impl::const_iterator end() const noexcept;

private:
    std::unordered_map<NSString *, LEGACYClassInfo> m_objects;
};

LEGACY_HEADER_AUDIT_END(nullability, sendability)
