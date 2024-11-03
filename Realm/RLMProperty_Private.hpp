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

#import <Realm/LEGACYProperty_Private.h>

#import <realm/object-store/property.hpp>

@class LEGACYSchema;

LEGACY_DIRECT_MEMBERS
@interface LEGACYProperty ()
+ (instancetype)propertyForObjectStoreProperty:(const realm::Property&)property;
- (realm::Property)objectStoreCopy:(LEGACYSchema *)schema;
@end

static inline bool isNullable(const realm::PropertyType& t) {
    return t != realm::PropertyType::Mixed && is_nullable(t);
}
