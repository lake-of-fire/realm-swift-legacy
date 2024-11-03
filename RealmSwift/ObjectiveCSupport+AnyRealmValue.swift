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


import Foundation
import RealmLegacy

public extension ObjectiveCSupport {

    /// Convert an object boxed in `AnyRealmValue` to its
    /// Objective-C representation.
    /// - Parameter value: The AnyRealmValue with the object.
    /// - Returns: Conversion of `value` to its Objective-C representation.
    static func convert(value: AnyRealmValue?) -> LEGACYValue? {
        switch value {
        case let .int(i):
            return i as NSNumber
        case let .bool(b):
            return b as NSNumber
        case let .float(f):
            return f as NSNumber
        case let .double(f):
            return f as NSNumber
        case let .string(s):
            return s as NSString
        case let .data(d):
            return d as NSData
        case let .date(d):
            return d as NSDate
        case let .objectId(o):
            return o as LEGACYObjectId
        case let .decimal128(o):
            return o as LEGACYDecimal128
        case let .uuid(u):
            return u as NSUUID
        case let .object(o):
            return o
        default:
            return nil
        }
    }

    /// Takes an LEGACYValue, converts it to its Swift type and
    /// stores it in `AnyRealmValue`.
    /// - Parameter value: The LEGACYValue.
    /// - Returns: The converted LEGACYValue type as an AnyRealmValue enum.
    static func convert(value: LEGACYValue?) -> AnyRealmValue {
        guard let value = value else {
            return .none
        }

        switch value.rlm_valueType {
        case LEGACYPropertyType.int:
            guard let val = value as? NSNumber else {
                return .none
            }
            return .int(val.intValue)
        case LEGACYPropertyType.bool:
            guard let val = value as? NSNumber else {
                return .none
            }
            return .bool(val.boolValue)
        case LEGACYPropertyType.float:
            guard let val = value as? NSNumber else {
                return .none
            }
            return .float(val.floatValue)
        case LEGACYPropertyType.double:
            guard let val = value as? NSNumber else {
                return .none
            }
            return .double(val.doubleValue)
        case LEGACYPropertyType.string:
            guard let val = value as? String else {
                return .none
            }
            return .string(val)
        case LEGACYPropertyType.data:
            guard let val = value as? Data else {
                return .none
            }
            return .data(val)
        case LEGACYPropertyType.date:
            guard let val = value as? Date else {
                return .none
            }
            return .date(val)
        case LEGACYPropertyType.objectId:
            guard let val = value as? ObjectId else {
                return .none
            }
            return .objectId(val)
        case LEGACYPropertyType.decimal128:
            guard let val = value as? Decimal128 else {
                return .none
            }
            return .decimal128(val)
        case LEGACYPropertyType.UUID:
            guard let val = value as? UUID else {
                return .none
            }
            return .uuid(val)
        case LEGACYPropertyType.object:
            guard let val = value as? Object else {
                return .none
            }
            return .object(val)
        default:
            return .none
        }
    }
}
