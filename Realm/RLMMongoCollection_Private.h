////////////////////////////////////////////////////////////////////////////
//
// Copyright 2020 Realm Inc.
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

#import <Realm/LEGACYMongoCollection.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability)

@class LEGACYUser;

@interface LEGACYMongoCollection ()
- (instancetype)initWithUser:(LEGACYUser *)user
                 serviceName:(NSString *)serviceName
                databaseName:(NSString *)databaseName
              collectionName:(NSString *)collectionName;

- (LEGACYChangeStream *)watchWithMatchFilter:(nullable id<LEGACYBSON>)matchFilter
                                 idFilter:(nullable id<LEGACYBSON>)idFilter
                                 delegate:(id<LEGACYChangeEventDelegate>)delegate
                                scheduler:(void (^)(dispatch_block_t))scheduler;
@end

LEGACY_HEADER_AUDIT_END(nullability)
