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

@class LEGACYRealm;

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

/**
 Objects of types which conform to `LEGACYThreadConfined` can be managed by a Realm, which will make
 them bound to a thread-specific `LEGACYRealm` instance. Managed objects must be explicitly exported
 and imported to be passed between threads.

 Managed instances of objects conforming to this protocol can be converted to a thread-safe
 reference for transport between threads by passing to the
 `+[LEGACYThreadSafeReference referenceWithThreadConfined:]` constructor.

 Note that only types defined by Realm can meaningfully conform to this protocol, and defining new
 classes which attempt to conform to it will not make them work with `LEGACYThreadSafeReference`.
 */
@protocol LEGACYThreadConfined <NSObject>
// Conformance to the `LEGACYThreadConfined_Private` protocol will be enforced at runtime.

/**
 The Realm which manages the object, or `nil` if the object is unmanaged.

 Unmanaged objects are not confined to a thread and cannot be passed to methods expecting a
 `LEGACYThreadConfined` object.
 */
@property (nonatomic, readonly, nullable) LEGACYRealm *realm;

/// Indicates if the object can no longer be accessed because it is now invalid.
@property (nonatomic, readonly, getter = isInvalidated) BOOL invalidated;

@end

/**
 An object intended to be passed between threads containing a thread-safe reference to its
 thread-confined object.

 To resolve a thread-safe reference on a target Realm on a different thread, pass to
 `-[LEGACYRealm resolveThreadSafeReference:]`.

 @warning A `LEGACYThreadSafeReference` object must be resolved at most once.
          Failing to resolve a `LEGACYThreadSafeReference` will result in the source version of the
          Realm being pinned until the reference is deallocated.

 @note Prefer short-lived `LEGACYThreadSafeReference`s as the data for the version of the source Realm
       will be retained until all references have been resolved or deallocated.

 @see `LEGACYThreadConfined`
 @see `-[LEGACYRealm resolveThreadSafeReference:]`
 */
LEGACY_SWIFT_SENDABLE LEGACY_FINAL // is internally thread-safe
@interface LEGACYThreadSafeReference<__covariant Confined : id<LEGACYThreadConfined>> : NSObject

/**
 Create a thread-safe reference to the thread-confined object.

 @param threadConfined The thread-confined object to create a thread-safe reference to.

 @note You may continue to use and access the thread-confined object after passing it to this
       constructor.
 */
+ (instancetype)referenceWithThreadConfined:(Confined)threadConfined;

/**
 Indicates if the reference can no longer be resolved because an attempt to resolve it has already
 occurred. References can only be resolved once.
 */
@property (nonatomic, readonly, getter = isInvalidated) BOOL invalidated;

#pragma mark - Unavailable Methods

/**
 `-[LEGACYThreadSafeReference init]` is not available because `LEGACYThreadSafeReference` cannot be
 created directly. `LEGACYThreadSafeReference` instances must be obtained by calling
 `-[LEGACYRealm resolveThreadSafeReference:]`.
 */
- (instancetype)init __attribute__((unavailable("LEGACYThreadSafeReference cannot be created directly")));

/**
 `-[LEGACYThreadSafeReference new]` is not available because `LEGACYThreadSafeReference` cannot be
 created directly. `LEGACYThreadSafeReference` instances must be obtained by calling
 `-[LEGACYRealm resolveThreadSafeReference:]`.
 */
+ (instancetype)new __attribute__((unavailable("LEGACYThreadSafeReference cannot be created directly")));

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
