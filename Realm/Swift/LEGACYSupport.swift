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

import RealmLegacy

extension LEGACYRealm {
    /**
     Returns the schema version for a Realm at a given local URL.

     - see: `+ [LEGACYRealm schemaVersionAtURL:encryptionKey:error:]`
     */
    @nonobjc public class func schemaVersion(at url: URL, usingEncryptionKey key: Data? = nil) throws -> UInt64 {
        var error: NSError?
        let version = __schemaVersion(at: url, encryptionKey: key, error: &error)
        guard version != LEGACYNotVersioned else { throw error! }
        return version
    }

    /**
     Returns the same object as the one referenced when the `LEGACYThreadSafeReference` was first created,
     but resolved for the current Realm for this thread. Returns `nil` if this object was deleted after
     the reference was created.

     - see `- [LEGACYRealm resolveThreadSafeReference:]`
     */
    @nonobjc public func resolve<Confined>(reference: LEGACYThreadSafeReference<Confined>) -> Confined? {
        return __resolve(reference as! LEGACYThreadSafeReference<LEGACYThreadConfined>) as! Confined?
    }
}

extension LEGACYObject {
    /**
     Returns all objects of this object type matching the given predicate from the default RealmLegacy.

     - see `+ [LEGACYObject objectsWithPredicate:]`
     */
    public class func objects(where predicateFormat: String, _ args: CVarArg...) -> LEGACYResults<LEGACYObject> {
        return objects(with: NSPredicate(format: predicateFormat, arguments: getVaList(args))) as! LEGACYResults<LEGACYObject>
    }

    /**
     Returns all objects of this object type matching the given predicate from the specified RealmLegacy.

     - see `+ [LEGACYObject objectsInRealm:withPredicate:]`
     */
    public class func objects(in realm: LEGACYRealm,
                              where predicateFormat: String,
                              _ args: CVarArg...) -> LEGACYResults<LEGACYObject> {
        return objects(in: realm, with: NSPredicate(format: predicateFormat, arguments: getVaList(args))) as! LEGACYResults<LEGACYObject>
    }
}

/// A protocol defining iterator support for LEGACYArray, LEGACYSet & LEGACYResults.
public protocol _LEGACYCollectionIterator {
    /**
     Returns a `LEGACYCollectionIterator` that yields successive elements in the collection.
     This enables support for sequence-style enumeration of `LEGACYObject` subclasses in Swift.
     */
    func makeIterator() -> LEGACYCollectionIterator
}

extension _LEGACYCollectionIterator where Self: LEGACYCollection {
    /// :nodoc:
    public func makeIterator() -> LEGACYCollectionIterator {
        return LEGACYCollectionIterator(self)
    }
}
/// :nodoc:
public typealias LEGACYDictionarySingleEntry = (key: String, value: LEGACYObject)
/// A protocol defining iterator support for LEGACYDictionary
public protocol _LEGACYDictionaryIterator {
    /// :nodoc:
    func makeIterator() -> LEGACYDictionaryIterator
}

extension _LEGACYDictionaryIterator where Self: LEGACYCollection {
    /// :nodoc:
    public func makeIterator() -> LEGACYDictionaryIterator {
        return LEGACYDictionaryIterator(self)
    }
}

// Sequence conformance for LEGACYArray, LEGACYDictionary, LEGACYSet and LEGACYResults is provided by LEGACYCollection's
// `makeIterator()` implementation.
extension LEGACYArray: Sequence, _LEGACYCollectionIterator { }
extension LEGACYDictionary: Sequence, _LEGACYDictionaryIterator {}
extension LEGACYSet: Sequence, _LEGACYCollectionIterator {}
extension LEGACYResults: Sequence, _LEGACYCollectionIterator {}

/**
 This struct enables sequence-style enumeration for LEGACYObjects in Swift via `LEGACYCollection.makeIterator`
 */
public struct LEGACYCollectionIterator: IteratorProtocol {
    private var iteratorBase: NSFastEnumerationIterator

    internal init(_ collection: LEGACYCollection) {
        iteratorBase = NSFastEnumerationIterator(collection)
    }

    public mutating func next() -> LEGACYObject? {
        return iteratorBase.next() as! LEGACYObject?
    }
}

/**
 This struct enables sequence-style enumeration for LEGACYDictionary in Swift via `LEGACYDictionary.makeIterator`
 */
public struct LEGACYDictionaryIterator: IteratorProtocol {
    private var iteratorBase: NSFastEnumerationIterator
    private let dictionary: LEGACYDictionary<AnyObject, AnyObject>

    internal init(_ collection: LEGACYCollection) {
        dictionary = collection as! LEGACYDictionary<AnyObject, AnyObject>
        iteratorBase = NSFastEnumerationIterator(collection)
    }

    public mutating func next() -> LEGACYDictionarySingleEntry? {
        let key = iteratorBase.next()
        if let key = key {
            return (key: key as Any, value: dictionary[key as AnyObject]) as? LEGACYDictionarySingleEntry
        }
        if key != nil {
            fatalError("unsupported key type")
        }
        return nil
    }
}

// Swift query convenience functions
extension LEGACYCollection {
    /**
     Returns the index of the first object in the collection matching the predicate.
     */
    public func indexOfObject(where predicateFormat: String, _ args: CVarArg...) -> UInt {
        guard let index = indexOfObject?(with: NSPredicate(format: predicateFormat, arguments: getVaList(args))) else {
            fatalError("This LEGACYCollection does not support indexOfObject(where:)")
        }
        return index
    }

    /**
     Returns all objects matching the given predicate in the collection.
     */
    public func objects(where predicateFormat: String, _ args: CVarArg...) -> LEGACYResults<NSObject> {
        return objects(with: NSPredicate(format: predicateFormat, arguments: getVaList(args))) as! LEGACYResults<NSObject>
    }
}

extension LEGACYCollection {
    /// Allows for subscript support with LEGACYDictionary.
    public subscript(_ key: String) -> AnyObject? {
        get {
            (self as! LEGACYDictionary<NSString, AnyObject>).object(forKey: key as NSString)
        }
        set {
            (self as! LEGACYDictionary<NSString, AnyObject>).setObject(newValue, forKey: key as NSString)
        }
    }
}
