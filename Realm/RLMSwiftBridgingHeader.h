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
#import <Realm/LEGACYObject.h>

@interface LEGACYRealm (Swift)
+ (void)resetRealmState;
@end

@interface LEGACYArray (Swift)

- (instancetype)initWithObjectClassName:(NSString *)objectClassName;

- (NSUInteger)indexOfObjectWhere:(NSString *)predicateFormat args:(va_list)args;
- (LEGACYResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args;

@end

@interface LEGACYResults (Swift)

- (NSUInteger)indexOfObjectWhere:(NSString *)predicateFormat args:(va_list)args;
- (LEGACYResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args;

@end

@interface LEGACYObjectBase (Swift)

- (instancetype)initWithRealm:(LEGACYRealm *)realm schema:(LEGACYObjectSchema *)schema defaultValues:(BOOL)useDefaults;

+ (LEGACYResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args;
+ (LEGACYResults *)objectsInRealm:(LEGACYRealm *)realm where:(NSString *)predicateFormat args:(va_list)args;

@end
