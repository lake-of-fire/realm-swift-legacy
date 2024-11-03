////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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

/**
 `ObjectiveCSupport` is a class providing methods for Swift/Objective-C interoperability.

 With `ObjectiveCSupport` you can either retrieve the internal ObjC representations of the Realm objects,
 or wrap ObjC Realm objects with their Swift equivalents.

 Use this to provide public APIs that support both platforms.

 :nodoc:
 **/
@frozen public struct ObjectiveCSupport {

    /// Convert a `Results` to a `LEGACYResults`.
    public static func convert<T>(object: Results<T>) -> LEGACYResults<AnyObject> {
        return object.collection as! LEGACYResults<AnyObject>
    }

    /// Convert a `LEGACYResults` to a `Results`.
    public static func convert(object: LEGACYResults<AnyObject>) -> Results<Object> {
        return Results(object)
    }

    /// Convert a `List` to a `LEGACYArray`.
    public static func convert<T>(object: List<T>) -> LEGACYArray<AnyObject> {
        return object.rlmArray
    }

    /// Convert a `MutableSet` to a `LEGACYSet`.
    public static func convert<T>(object: MutableSet<T>) -> LEGACYSet<AnyObject> {
        return object.rlmSet
    }

    /// Convert a `LEGACYArray` to a `List`.
    public static func convert(object: LEGACYArray<AnyObject>) -> List<Object> {
        return List(collection: object)
    }

    /// Convert a `LEGACYSet` to a `MutableSet`.
    public static func convert(object: LEGACYSet<AnyObject>) -> MutableSet<Object> {
        return MutableSet(collection: object)
    }

    /// Convert a `Map` to a `LEGACYDictionary`.
    public static func convert<Key, Value>(object: Map<Key, Value>) -> LEGACYDictionary<AnyObject, AnyObject> {
        return object.rlmDictionary
    }

    /// Convert a `LEGACYDictionary` to a `Map`.
    public static func convert<Key>(object: LEGACYDictionary<AnyObject, AnyObject>) -> Map<Key, Object> {
        return Map(objc: object)
    }

    /// Convert a `LinkingObjects` to a `LEGACYResults`.
    public static func convert<T>(object: LinkingObjects<T>) -> LEGACYResults<AnyObject> {
        return object.collection as! LEGACYResults<AnyObject>
    }

    /// Convert a `LEGACYLinkingObjects` to a `Results`.
    public static func convert(object: LEGACYLinkingObjects<LEGACYObject>) -> Results<Object> {
        return Results(object)
    }

    /// Convert a `Realm` to a `LEGACYRealm`.
    public static func convert(object: RealmLegacy) -> LEGACYRealm {
        return object.rlmRealm
    }

    /// Convert a `LEGACYRealm` to a `Realm`.
    public static func convert(object: LEGACYRealm) -> RealmLegacy {
        return RealmLegacy(object)
    }

    /// Convert a `Migration` to a `LEGACYMigration`.
    @available(*, deprecated, message: "This function is now redundant")
    public static func convert(object: Migration) -> LEGACYMigration {
        return object
    }

    /// Convert a `ObjectSchema` to a `LEGACYObjectSchema`.
    public static func convert(object: ObjectSchema) -> LEGACYObjectSchema {
        return object.rlmObjectSchema
    }

    /// Convert a `LEGACYObjectSchema` to a `ObjectSchema`.
    public static func convert(object: LEGACYObjectSchema) -> ObjectSchema {
        return ObjectSchema(object)
    }

    /// Convert a `Property` to a `LEGACYProperty`.
    public static func convert(object: Property) -> LEGACYProperty {
        return object.rlmProperty
    }

    /// Convert a `LEGACYProperty` to a `Property`.
    public static func convert(object: LEGACYProperty) -> Property {
        return Property(object)
    }

    /// Convert a `Realm.Configuration` to a `LEGACYRealmConfiguration`.
    public static func convert(object: RealmLegacy.Configuration) -> LEGACYRealmConfiguration {
        return object.rlmConfiguration
    }

    /// Convert a `LEGACYRealmConfiguration` to a `Realm.Configuration`.
    public static func convert(object: LEGACYRealmConfiguration) -> RealmLegacy.Configuration {
        return .fromLEGACYRealmConfiguration(object)
    }

    /// Convert a `Schema` to a `LEGACYSchema`.
    public static func convert(object: Schema) -> LEGACYSchema {
        return object.rlmSchema
    }

    /// Convert a `LEGACYSchema` to a `Schema`.
    public static func convert(object: LEGACYSchema) -> Schema {
        return Schema(object)
    }

    /// Convert a `SortDescriptor` to a `LEGACYSortDescriptor`.
    public static func convert(object: SortDescriptor) -> LEGACYSortDescriptor {
        return object.rlmSortDescriptorValue
    }

    /// Convert a `LEGACYSortDescriptor` to a `SortDescriptor`.
    public static func convert(object: LEGACYSortDescriptor) -> SortDescriptor {
        return SortDescriptor(keyPath: object.keyPath, ascending: object.ascending)
    }

    /// Convert a `LEGACYShouldCompactOnLaunchBlock` to a Realm Swift compact block.
    @preconcurrency
    public static func convert(object: @escaping LEGACYShouldCompactOnLaunchBlock) -> @Sendable (Int, Int) -> Bool {
        return { totalBytes, usedBytes in
            return object(UInt(totalBytes), UInt(usedBytes))
        }
    }

    /// Convert a Realm Swift compact block to a `LEGACYShouldCompactOnLaunchBlock`.
    @preconcurrency
    public static func convert(object: @Sendable @escaping (Int, Int) -> Bool) -> LEGACYShouldCompactOnLaunchBlock {
        return { totalBytes, usedBytes in
            return object(Int(totalBytes), Int(usedBytes))
        }
    }

    /// Convert a RealmSwift before block to an LEGACYClientResetBeforeBlock
    @preconcurrency
    public static func convert(object: (@Sendable (RealmLegacy) -> Void)?) -> LEGACYClientResetBeforeBlock? {
        guard let object = object else {
            return nil
        }
        return { localRealm in
            return object(RealmLegacy(localRealm))
        }
    }

    /// Convert an LEGACYClientResetBeforeBlock to a RealmSwift before  block
    @preconcurrency
    public static func convert(object: LEGACYClientResetBeforeBlock?) -> (@Sendable (RealmLegacy) -> Void)? {
        guard let object = object else {
            return nil
        }
        return { localRealm in
            return object(localRealm.rlmRealm)
        }
    }

    /// Convert a RealmSwift after block to an LEGACYClientResetAfterBlock
    @preconcurrency
    public static func convert(object: (@Sendable (RealmLegacy, RealmLegacy) -> Void)?) -> LEGACYClientResetAfterBlock? {
        guard let object = object else {
            return nil
        }
        return { localRealm, remoteRealm in
            return object(RealmLegacy(localRealm), RealmLegacy(remoteRealm))
        }
    }

    /// Convert an LEGACYClientResetAfterBlock to a RealmSwift after block
    @preconcurrency
    public static func convert(object: LEGACYClientResetAfterBlock?) -> (@Sendable (RealmLegacy, RealmLegacy) -> Void)? {
        guard let object = object else {
            return nil
        }
        return { localRealm, remoteRealm in
            return object(localRealm.rlmRealm, remoteRealm.rlmRealm)
        }
    }

    /// Converts a swift block receiving a `SyncSubscriptionSet`to a LEGACYFlexibleSyncInitialSubscriptionsBlock receiving a `LEGACYSyncSubscriptionSet`.
    @preconcurrency
    public static func convert(block: @escaping @Sendable (SyncSubscriptionSet) -> Void) -> LEGACYFlexibleSyncInitialSubscriptionsBlock {
        return { subscriptionSet in
            return block(SyncSubscriptionSet(subscriptionSet))
        }
    }

    /// Converts a block receiving a `LEGACYSyncSubscriptionSet`to a swift block receiving a `SyncSubscriptionSet`.
    @preconcurrency
    public static func convert(block: LEGACYFlexibleSyncInitialSubscriptionsBlock?) -> (@Sendable (SyncSubscriptionSet) -> Void)? {
        guard let block = block else {
            return nil
        }
        return { subscriptionSet in
            return block(subscriptionSet.rlmSyncSubscriptionSet)
        }
    }

    /// Converts a block receiving a `LEGACYSyncSubscriptionSet`to a swift block receiving a `SyncSubscriptionSet`.
    @preconcurrency
    public static func convert(block: @escaping LEGACYFlexibleSyncInitialSubscriptionsBlock) -> @Sendable (SyncSubscriptionSet) -> Void {
        return { subscriptionSet in
            return block(subscriptionSet.rlmSyncSubscriptionSet)
        }
    }
}
