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

#import <Realm/LEGACYArray.h>
#import <Realm/LEGACYConstants.h>

@class LEGACYObjectBase, LEGACYProperty;

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface LEGACYArray ()
- (instancetype)initWithObjectClassName:(NSString *)objectClassName;
- (instancetype)initWithObjectType:(LEGACYPropertyType)type optional:(BOOL)optional;
- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth;
- (void)setParent:(LEGACYObjectBase *)parentObject property:(LEGACYProperty *)property;
- (void)replaceAllObjectsWithObjects:(NSArray *)objects;
// YES if the property is declared with old property syntax.
@property (nonatomic, readonly) BOOL isLegacyProperty;
// The name of the property which this collection represents
@property (nonatomic, readonly) NSString *propertyKey;
@end

@interface LEGACYManagedArray : LEGACYArray
- (instancetype)initWithParent:(LEGACYObjectBase *)parentObject property:(LEGACYProperty *)property;
@end

void LEGACYArrayValidateMatchingObjectType(LEGACYArray *array, id value);

LEGACY_HEADER_AUDIT_END(nullability, sendability)
