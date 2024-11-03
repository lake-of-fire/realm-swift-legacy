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

#import <Realm/LEGACYCollection.h>

@class LEGACYObjectBase, LEGACYResults, LEGACYProperty, LEGACYLinkingObjects;

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface LEGACYSwiftCollectionBase : NSProxy <NSFastEnumeration>
@property (nonatomic, strong) id<LEGACYCollection> _rlmCollection;

- (instancetype)init;
+ (Class)_backingCollectionType;
- (instancetype)initWithCollection:(id<LEGACYCollection>)collection;

- (nullable id)valueForKey:(NSString *)key;
- (nullable id)valueForKeyPath:(NSString *)keyPath;
- (BOOL)isEqual:(nullable id)object;
@end

@interface LEGACYLinkingObjectsHandle : NSObject
- (instancetype)initWithObject:(LEGACYObjectBase *)object property:(LEGACYProperty *)property;
- (instancetype)initWithLinkingObjects:(LEGACYResults *)linkingObjects;

@property (nonatomic, readonly) LEGACYLinkingObjects *results;
@property (nonatomic, readonly) NSString *_propertyKey;
@property (nonatomic, readonly) BOOL _isLegacyProperty;
@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
