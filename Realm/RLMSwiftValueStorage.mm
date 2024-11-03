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

#import "LEGACYSwiftValueStorage.h"

#import "LEGACYAccessor.hpp"
#import "LEGACYObject_Private.hpp"
#import "LEGACYProperty_Private.h"
#import "LEGACYUtil.hpp"

#import <realm/object-store/object.hpp>

namespace {
struct SwiftValueStorageBase {
    virtual id get() = 0;
    virtual void set(id) = 0;
    virtual NSString *propertyName() = 0;
    virtual ~SwiftValueStorageBase() = default;
};

class UnmanagedSwiftValueStorage : public SwiftValueStorageBase {
public:
    id get() override {
        return _value;
    }

    void set(__unsafe_unretained const id newValue) override {
        @autoreleasepool {
            LEGACYObjectBase *object = _parent;
            [object willChangeValueForKey:_property];
            _value = newValue;
            [object didChangeValueForKey:_property];
        }
    }

    void attach(__unsafe_unretained LEGACYObjectBase *const obj, NSString *property) {
        if (!_property) {
            _property = property;
            _parent = obj;
        }
    }

    NSString *propertyName() override {
        return _property;
    }

private:
    id _value;
    NSString *_property;
    __weak LEGACYObjectBase *_parent;

};

class ManagedSwiftValueStorage : public SwiftValueStorageBase {
public:
    ManagedSwiftValueStorage(LEGACYObjectBase *obj, LEGACYProperty *prop)
    : _realm(obj->_realm)
    , _object(obj->_realm->_realm, *obj->_info->objectSchema, obj->_row)
    , _columnName(prop.columnName.UTF8String)
    , _ctx(*obj->_info)
    {
    }

    id get() override {
        return _object.get_property_value<id>(_ctx, _columnName);
    }

    void set(__unsafe_unretained id const value) override {
        _object.set_property_value(_ctx, _columnName, value ?: NSNull.null);
    }

    NSString *propertyName() override {
        // Should never be called on a managed object.
        REALM_UNREACHABLE();
    }

private:
    // We have to hold onto a strong reference to the Realm as
    // LEGACYAccessorContext holds a non-retaining one.
    __unused LEGACYRealm *_realm;
    realm::Object _object;
    std::string _columnName;
    LEGACYAccessorContext _ctx;
};
} // anonymous namespace

@interface LEGACYSwiftValueStorage () {
    std::unique_ptr<SwiftValueStorageBase> _impl;
}
@end

@implementation LEGACYSwiftValueStorage
- (instancetype)init {
    return self;
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [LEGACYGetSwiftValueStorage(self) isKindOfClass:aClass] || LEGACYIsKindOfClass(object_getClass(self), aClass);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [LEGACYGetSwiftValueStorage(self) methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:LEGACYGetSwiftValueStorage(self)];
}

- (id)forwardingTargetForSelector:(__unused SEL)sel {
    return LEGACYGetSwiftValueStorage(self);
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [LEGACYGetSwiftValueStorage(self) respondsToSelector:aSelector];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    [LEGACYGetSwiftValueStorage(self) doesNotRecognizeSelector:aSelector];
}

id LEGACYGetSwiftValueStorage(__unsafe_unretained LEGACYSwiftValueStorage *const self) {
    try {
        return self->_impl ? LEGACYCoerceToNil(self->_impl->get()) : nil;
    }
    catch (std::exception const& err) {
        @throw LEGACYException(err);
    }
}

void LEGACYSetSwiftValueStorage(__unsafe_unretained LEGACYSwiftValueStorage *const self, __unsafe_unretained const id value) {
    try {
        if (!self->_impl && value) {
            self->_impl.reset(new UnmanagedSwiftValueStorage);
        }
        if (self->_impl) {
            self->_impl->set(value);
        }
    }
    catch (std::exception const& err) {
        @throw LEGACYException(err);
    }
}

void LEGACYInitializeManagedSwiftValueStorage(__unsafe_unretained LEGACYSwiftValueStorage *const self,
                                  __unsafe_unretained LEGACYObjectBase *const parent,
                                  __unsafe_unretained LEGACYProperty *const prop) {
    REALM_ASSERT(parent->_realm);
    self->_impl.reset(new ManagedSwiftValueStorage(parent, prop));
}

void LEGACYInitializeUnmanagedSwiftValueStorage(__unsafe_unretained LEGACYSwiftValueStorage *const self,
                                    __unsafe_unretained LEGACYObjectBase *const parent,
                                    __unsafe_unretained LEGACYProperty *const prop) {
    if (parent->_realm) {
        return;
    }
    if (!self->_impl) {
        self->_impl.reset(new UnmanagedSwiftValueStorage);
    }
    static_cast<UnmanagedSwiftValueStorage&>(*self->_impl).attach(parent, prop.name);
}

NSString *LEGACYSwiftValueStorageGetPropertyName(LEGACYSwiftValueStorage *const self) {
    return self->_impl->propertyName();
}

@end
