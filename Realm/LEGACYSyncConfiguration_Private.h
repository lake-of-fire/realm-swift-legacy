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

#import <Realm/LEGACYSyncConfiguration.h>

#import <Realm/LEGACYConstants.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

typedef LEGACY_CLOSED_ENUM(NSUInteger, LEGACYSyncStopPolicy) {
    LEGACYSyncStopPolicyImmediately,
    LEGACYSyncStopPolicyLiveIndefinitely,
    LEGACYSyncStopPolicyAfterChangesUploaded,
};


@class LEGACYSchema;

@interface LEGACYSyncConfiguration ()

// Flexible sync
- (instancetype)initWithUser:(LEGACYUser *)user;
// Partition-based sync
- (instancetype)initWithUser:(LEGACYUser *)user
              partitionValue:(nullable id<LEGACYBSON>)partitionValue;

// Internal-only APIs
@property (nonatomic, readwrite) LEGACYSyncStopPolicy stopPolicy;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
