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

#import <Realm/LEGACYDictionary.h>

@class LEGACYObjectBase, LEGACYProperty;

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface LEGACYDictionary ()
- (instancetype)initWithObjectClassName:(NSString *)objectClassName keyType:(LEGACYPropertyType)keyType;
- (instancetype)initWithObjectType:(LEGACYPropertyType)type optional:(BOOL)optional keyType:(LEGACYPropertyType)keyType;
- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth;
- (void)setParent:(LEGACYObjectBase *)parentObject property:(LEGACYProperty *)property;
// YES if the property is declared with old property syntax.
@property (nonatomic, readonly) BOOL isLegacyProperty;
// The name of the property which this collection represents
@property (nonatomic, readonly) NSString *propertyKey;
@end

@interface LEGACYManagedDictionary : LEGACYDictionary
- (instancetype)initWithParent:(LEGACYObjectBase *)parentObject property:(LEGACYProperty *)property;
@end

FOUNDATION_EXTERN NSString *LEGACYDictionaryDescriptionWithMaxDepth(NSString *name,
                                                                 LEGACYDictionary *dictionary,
                                                                 NSUInteger depth);
id LEGACYDictionaryKey(LEGACYDictionary *dictionary, id key) LEGACY_HIDDEN;
id LEGACYDictionaryValue(LEGACYDictionary *dictionary, id value) LEGACY_HIDDEN;

LEGACY_HEADER_AUDIT_END(nullability, sendability)
