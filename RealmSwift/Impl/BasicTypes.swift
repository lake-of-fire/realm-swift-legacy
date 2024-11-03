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

import RealmLegacy
import RealmLegacy.Private

// MARK: - Property Types

extension Int: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .int }
}

extension Int8: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .int }
}

extension Int16: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .int }
}

extension Int32: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .int }
}

extension Int64: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .int }
}

extension Bool: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .bool }
}

extension Float: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .float }
}

extension Double: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .double }
}

extension String: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .string }
}

extension Data: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .data }
}

extension ObjectId: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .objectId }
}

extension Decimal128: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .decimal128 }
}

extension Date: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .date }
}

extension UUID: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .UUID }
}

extension AnyRealmValue: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .any }
    public static func _rlmPopulateProperty(_ prop: LEGACYProperty) {
        if prop.optional {
            var type = "AnyRealmValue"
            if prop.array {
                type = "List<AnyRealmValue>"
            } else if prop.set {
                type = "MutableSet<AnyRealmValue>"
            } else if prop.dictionary {
                type = "Map<String, AnyRealmValue>"
            }
            throwRealmException("\(type) property '\(prop.name)' must not be marked as optional: nil values are represented as AnyRealmValue.none")
        }
    }
}

extension NSString: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .string }
}

extension NSData: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .data }
}

extension NSDate: SchemaDiscoverable {
    public static var _rlmType: PropertyType { .date }
}

// MARK: - Modern property getters/setters

private protocol _Int: BinaryInteger, _PersistableInsideOptional, _DefaultConstructible, _PrimaryKey, _Indexable {
}

extension _Int {
    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> Self {
        return Self(LEGACYGetSwiftPropertyInt64(obj, key))
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> Self? {
        var gotValue = false
        let ret = LEGACYGetSwiftPropertyInt64Optional(obj, key, &gotValue)
        return gotValue ? Self(ret) : nil
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: Self) {
        LEGACYSetSwiftPropertyInt64(obj, key, Int64(value))
    }
}

extension Int: _Int {
    public typealias PersistedType = Int
}
extension Int8: _Int {
    public typealias PersistedType = Int8
}
extension Int16: _Int {
    public typealias PersistedType = Int16
}
extension Int32: _Int {
    public typealias PersistedType = Int32
}
extension Int64: _Int {
    public typealias PersistedType = Int64
}

extension Bool: _PersistableInsideOptional, _DefaultConstructible, _PrimaryKey, _Indexable {
    public typealias PersistedType = Bool

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> Bool {
        return LEGACYGetSwiftPropertyBool(obj, key)
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> Bool? {
        var gotValue = false
        let ret = LEGACYGetSwiftPropertyBoolOptional(obj, key, &gotValue)
        return gotValue ? ret : nil
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: Bool) {
        LEGACYSetSwiftPropertyBool(obj, key, (value))
    }
}

extension Float: _PersistableInsideOptional, _DefaultConstructible {
    public typealias PersistedType = Float

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> Float {
        return LEGACYGetSwiftPropertyFloat(obj, key)
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> Float? {
        var gotValue = false
        let ret = LEGACYGetSwiftPropertyFloatOptional(obj, key, &gotValue)
        return gotValue ? ret : nil
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: Float) {
        LEGACYSetSwiftPropertyFloat(obj, key, (value))
    }
}

extension Double: _PersistableInsideOptional, _DefaultConstructible {
    public typealias PersistedType = Double

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> Double {
        return LEGACYGetSwiftPropertyDouble(obj, key)
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> Double? {
        var gotValue = false
        let ret = LEGACYGetSwiftPropertyDoubleOptional(obj, key, &gotValue)
        return gotValue ? ret : nil
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: Double) {
        LEGACYSetSwiftPropertyDouble(obj, key, (value))
    }
}

extension String: _PersistableInsideOptional, _DefaultConstructible, _PrimaryKey, _Indexable {
    public typealias PersistedType = String

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> String {
        return LEGACYGetSwiftPropertyString(obj, key)!
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> String? {
        return LEGACYGetSwiftPropertyString(obj, key)
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: String) {
        LEGACYSetSwiftPropertyString(obj, key, value)
    }
}

extension Data: _PersistableInsideOptional, _DefaultConstructible {
    public typealias PersistedType = Data

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> Data {
        return LEGACYGetSwiftPropertyData(obj, key)!
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> Data? {
        return LEGACYGetSwiftPropertyData(obj, key)
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: Data) {
        LEGACYSetSwiftPropertyData(obj, key, value)
    }
}

extension ObjectId: _PersistableInsideOptional, _DefaultConstructible, _PrimaryKey, _Indexable {
    public typealias PersistedType = ObjectId

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> ObjectId {
        return LEGACYGetSwiftPropertyObjectId(obj, key) as! ObjectId
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> ObjectId? {
        return LEGACYGetSwiftPropertyObjectId(obj, key).flatMap(failableStaticBridgeCast)
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: ObjectId) {
        LEGACYSetSwiftPropertyObjectId(obj, key, (value))
    }

    public static func _rlmDefaultValue() -> ObjectId {
        return Self.generate()
    }
}

extension Decimal128: _PersistableInsideOptional, _DefaultConstructible {
    public typealias PersistedType = Decimal128

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> Decimal128 {
        return LEGACYGetSwiftPropertyDecimal128(obj, key) as! Decimal128
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> Decimal128? {
        return LEGACYGetSwiftPropertyDecimal128(obj, key).flatMap(failableStaticBridgeCast)
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: Decimal128) {
        LEGACYSetSwiftPropertyDecimal128(obj, key, value)
    }
}

extension Date: _PersistableInsideOptional, _DefaultConstructible, _Indexable {
    public typealias PersistedType = Date

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> Date {
        return LEGACYGetSwiftPropertyDate(obj, key)!
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> Date? {
        return LEGACYGetSwiftPropertyDate(obj, key)
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: Date) {
        LEGACYSetSwiftPropertyDate(obj, key, value)
    }
}

extension UUID: _PersistableInsideOptional, _DefaultConstructible, _PrimaryKey, _Indexable {
    public typealias PersistedType = UUID

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> UUID {
        return LEGACYGetSwiftPropertyUUID(obj, key)!
    }

    @inlinable
    public static func _rlmGetPropertyOptional(_ obj: ObjectBase, _ key: PropertyKey) -> UUID? {
        return LEGACYGetSwiftPropertyUUID(obj, key)
    }

    @inlinable
    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: UUID) {
        LEGACYSetSwiftPropertyUUID(obj, key, value)
    }
}

extension AnyRealmValue: _Persistable, _DefaultConstructible {
    public typealias PersistedType = AnyRealmValue

    @inlinable
    public static func _rlmGetProperty(_ obj: ObjectBase, _ key: PropertyKey) -> AnyRealmValue {
        return ObjectiveCSupport.convert(value: LEGACYGetSwiftPropertyAny(obj, key))
    }

    public static func _rlmSetProperty(_ obj: ObjectBase, _ key: PropertyKey, _ value: AnyRealmValue) {
        LEGACYSetSwiftPropertyAny(obj, key, value._rlmObjcValue as! LEGACYValue)
    }

    public static func _rlmSetAccessor(_ prop: LEGACYProperty) {
        prop.swiftAccessor = BridgedPersistedPropertyAccessor<Self>.self
    }
}
