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

#import <Realm/LEGACYConstants.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@class LEGACYObjectBase, LEGACYProperty;

/// This class implements the backing storage for `RealmProperty<>` and `RealmOptional<>`.
/// This class should not be subclassed or used directly.
@interface LEGACYSwiftValueStorage : NSProxy
- (instancetype)init;
@end
/// Retrieves the value that is stored, or nil if it is empty.
FOUNDATION_EXTERN id _Nullable LEGACYGetSwiftValueStorage(LEGACYSwiftValueStorage *);
/// Sets a value on the property this instance represents for an object.
FOUNDATION_EXTERN void LEGACYSetSwiftValueStorage(LEGACYSwiftValueStorage *, id _Nullable);

/// Initialises managed accessors on an instance of `LEGACYSwiftValueStorage`
/// @param parent The enclosing parent object.
/// @param prop The property which this class represents.
FOUNDATION_EXTERN void LEGACYInitializeManagedSwiftValueStorage(LEGACYSwiftValueStorage *,
                                                             LEGACYObjectBase *parent,
                                                             LEGACYProperty *prop);

/// Initialises unmanaged accessors on an instance of `LEGACYSwiftValueStorage`
/// @param parent The enclosing parent object.
/// @param prop The property which this class represents.
FOUNDATION_EXTERN void LEGACYInitializeUnmanagedSwiftValueStorage(LEGACYSwiftValueStorage *,
                                                               LEGACYObjectBase *parent,
                                                               LEGACYProperty *prop);

/// Gets the property name for the RealmProperty instance. This is required for tracing the key path on
/// objects that use the legacy property declaration syntax.
FOUNDATION_EXTERN NSString *LEGACYSwiftValueStorageGetPropertyName(LEGACYSwiftValueStorage *);

LEGACY_HEADER_AUDIT_END(nullability, sendability)
