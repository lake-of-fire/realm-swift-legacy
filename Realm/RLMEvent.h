////////////////////////////////////////////////////////////////////////////
//
// Copyright 2022 Realm Inc.
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

#ifdef __cplusplus
#include <memory>

namespace realm {
struct AuditConfig;
}
#endif

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@class LEGACYRealm, LEGACYUser, LEGACYRealmConfiguration;
typedef LEGACY_CLOSED_ENUM(NSUInteger, LEGACYSyncLogLevel);

struct LEGACYEventContext;
typedef void (^LEGACYEventCompletion)(NSError *_Nullable);

FOUNDATION_EXTERN struct LEGACYEventContext *_Nullable LEGACYEventGetContext(LEGACYRealm *realm);
FOUNDATION_EXTERN uint64_t LEGACYEventBeginScope(struct LEGACYEventContext *context, NSString *activity);
FOUNDATION_EXTERN void LEGACYEventCommitScope(struct LEGACYEventContext *context, uint64_t scope_id,
                                           LEGACYEventCompletion _Nullable completion);
FOUNDATION_EXTERN void LEGACYEventCancelScope(struct LEGACYEventContext *context, uint64_t scope_id);
FOUNDATION_EXTERN bool LEGACYEventIsActive(struct LEGACYEventContext *context, uint64_t scope_id);
FOUNDATION_EXTERN void LEGACYEventRecordEvent(struct LEGACYEventContext *context, NSString *activity,
                                           NSString *_Nullable event, NSString *_Nullable data,
                                           LEGACYEventCompletion _Nullable completion);
FOUNDATION_EXTERN void LEGACYEventUpdateMetadata(struct LEGACYEventContext *context,
                                              NSDictionary<NSString *, NSString *> *newMetadata);

@interface LEGACYEventConfiguration : NSObject
@property (nonatomic) NSString *partitionPrefix;
@property (nonatomic, nullable) LEGACYUser *syncUser;
@property (nonatomic, nullable) NSDictionary<NSString *, NSString *> *metadata;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic, nullable) void (^logger)(LEGACYSyncLogLevel, NSString *);
#pragma clang diagnostic pop
@property (nonatomic, nullable) LEGACY_SWIFT_SENDABLE void (^errorHandler)(NSError *);

#ifdef __cplusplus
- (std::shared_ptr<realm::AuditConfig>)auditConfigWithRealmConfiguration:(LEGACYRealmConfiguration *)realmConfig;
#endif
@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
