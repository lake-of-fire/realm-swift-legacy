////////////////////////////////////////////////////////////////////////////
//
// Copyright 2023 Realm Inc.
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

#import <Realm/LEGACYAsyncTask.h>

#import "LEGACYRealm_Private.h"

LEGACY_HEADER_AUDIT_BEGIN(nullability)

@interface LEGACYAsyncOpenTask ()
@property (nonatomic, nullable) LEGACYRealm *localRealm;

- (instancetype)initWithConfiguration:(LEGACYRealmConfiguration *)configuration
                           confinedTo:(LEGACYScheduler *)confinement
                             download:(bool)waitForDownloadCompletion
                           completion:(LEGACYAsyncOpenRealmCallback)completion
__attribute__((objc_direct));

- (instancetype)initWithConfiguration:(LEGACYRealmConfiguration *)configuration
                           confinedTo:(LEGACYScheduler *)confinement
                             download:(bool)waitForDownloadCompletion;

- (void)waitWithCompletion:(void (^)(NSError *_Nullable))completion;
- (void)waitForOpen:(LEGACYAsyncOpenRealmCallback)completion __attribute__((objc_direct));
@end

// A cancellable task for waiting for downloads on an already-open Realm.
LEGACY_SWIFT_SENDABLE
@interface LEGACYAsyncDownloadTask : NSObject
- (instancetype)initWithRealm:(LEGACYRealm *)realm;
- (void)cancel;
- (void)waitWithCompletion:(void (^)(NSError *_Nullable))completion;
@end

// A cancellable task for beginning an async write
LEGACY_SWIFT_SENDABLE
@interface LEGACYAsyncWriteTask : NSObject
// Must only be called from within the Actor
- (instancetype)initWithRealm:(LEGACYRealm *)realm;
- (void)setTransactionId:(LEGACYAsyncTransactionId)transactionID;
- (void)complete:(bool)cancel;

// Can be called from any thread
- (void)wait:(void (^)(void))completion;
@end

typedef void (^LEGACYAsyncRefreshCompletion)(bool);
// A cancellable task for refreshing a Realm
LEGACY_SWIFT_SENDABLE
@interface LEGACYAsyncRefreshTask : NSObject
- (void)complete:(bool)didRefresh;
- (void)wait:(LEGACYAsyncRefreshCompletion)completion;
+ (LEGACYAsyncRefreshTask *)completedRefresh;
@end

// A cancellable task for refreshing a Realm
LEGACY_SWIFT_SENDABLE
@interface LEGACYAsyncSubscriptionTask : NSObject

- (instancetype)initWithSubscriptionSet:(LEGACYSyncSubscriptionSet *)subscriptionSet
                                  queue:(nullable dispatch_queue_t)queue
                                timeout:(NSTimeInterval)timeout
                             completion:(void(^)(NSError *))completion;

- (void)waitForSubscription;
@end

LEGACY_HEADER_AUDIT_END(nullability)
