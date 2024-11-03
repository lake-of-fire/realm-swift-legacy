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

#import "LEGACYSwiftCollectionBase.h"

#import "LEGACYArray_Private.hpp"
#import "LEGACYObjectSchema_Private.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYObservation.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYSet_Private.hpp"
#import "LEGACYDictionary_Private.hpp"

@interface LEGACYArray (KVO)
- (NSArray *)objectsAtIndexes:(__unused NSIndexSet *)indexes;
@end

// Some of the things declared in the interface are handled by the proxy forwarding
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation LEGACYSwiftCollectionBase

+ (id<LEGACYCollection>)_unmanagedCollection {
    return nil;
}

+ (Class)_backingCollectionType {
    REALM_UNREACHABLE();
}

- (instancetype)init {
    return self;
}

- (instancetype)initWithCollection:(id<LEGACYCollection>)collection {
    __rlmCollection = collection;
    return self;
}

- (id<LEGACYCollection>)_rlmCollection {
    if (!__rlmCollection) {
        __rlmCollection = self.class._unmanagedCollection;
    }
    return __rlmCollection;
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [self._rlmCollection isKindOfClass:aClass] || LEGACYIsKindOfClass(object_getClass(self), aClass);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [(id)self._rlmCollection methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self._rlmCollection];
}

- (id)forwardingTargetForSelector:(__unused SEL)sel {
    return self._rlmCollection;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [self._rlmCollection respondsToSelector:aSelector];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    [(id)self._rlmCollection doesNotRecognizeSelector:aSelector];
}

- (BOOL)isEqual:(id)object {
    if (auto collection = LEGACYDynamicCast<LEGACYSwiftCollectionBase>(object)) {
        if (!__rlmCollection) {
            return !collection->__rlmCollection.realm && collection->__rlmCollection.count == 0;
        }
        return  [__rlmCollection isEqual:collection->__rlmCollection];
    }
    return NO;
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return aProtocol == @protocol(NSFastEnumeration) || [self._rlmCollection conformsToProtocol:aProtocol];
}

@end

#pragma clang diagnostic pop

@implementation LEGACYLinkingObjectsHandle {
    realm::TableKey _tableKey;
    realm::ObjKey _objKey;
    LEGACYClassInfo *_info;
    LEGACYRealm *_realm;
    LEGACYProperty *_property;

    LEGACYResults *_results;
}

- (instancetype)initWithObject:(LEGACYObjectBase *)object property:(LEGACYProperty *)prop {
    if (!(self = [super init])) {
        return nil;
    }
    // KeyPath strings will invoke this initializer with an unmanaged object
    // so guard against that.
    if (object->_realm) {
        auto& obj = object->_row;
        _tableKey = obj.get_table()->get_key();
        _objKey = obj.get_key();
        _info = object->_info;
        _realm = object->_realm;
    }
    _property = prop;

    return self;
}

- (instancetype)initWithLinkingObjects:(LEGACYResults *)linkingObjects {
    if (!(self = [super init])) {
        return nil;
    }
    _realm = linkingObjects.realm;
    _results = linkingObjects;

    return self;
}

- (LEGACYResults *)results {
    if (_results) {
        return _results;
    }
    [_realm verifyThread];

    auto table = _realm.group.get_table(_tableKey);
    if (!table->is_valid(_objKey)) {
        @throw LEGACYException(@"Object has been deleted or invalidated.");
    }

    auto obj = _realm.group.get_table(_tableKey)->get_object(_objKey);
    auto& objectInfo = _realm->_info[_property.objectClassName];
    auto& linkOrigin = _info->objectSchema->computed_properties[_property.index].link_origin_property_name;
    auto linkingProperty = objectInfo.objectSchema->property_for_name(linkOrigin);
    realm::Results results(_realm->_realm, obj.get_backlink_view(objectInfo.table(), linkingProperty->column_key));
    _results = [LEGACYLinkingObjects resultsWithObjectInfo:objectInfo results:std::move(results)];
    _realm = nil;
    return _results;
}

- (NSString *)_propertyKey {
    return _property.name;
}

- (BOOL)_isLegacyProperty {
    return _property.isLegacy;
}

@end
