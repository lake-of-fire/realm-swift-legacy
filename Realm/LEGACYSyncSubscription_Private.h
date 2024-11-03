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

#import <Realm/LEGACYSyncSubscription.h>

#import <Realm/LEGACYRealm.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

#pragma mark - Subscription

@interface LEGACYSyncSubscription ()

@property (nonatomic, readonly) LEGACYObjectId *identifier;

@property (nonatomic, readonly) NSString *queryString;

@property (nonatomic, readonly) NSString *objectClassName;

@end

#pragma mark - SubscriptionSet

@interface LEGACYSyncSubscriptionEnumerator : NSObject

@property (nonatomic, readonly) LEGACYSyncSubscriptionSet *subscriptionSet;

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len;

- (instancetype)initWithSubscriptionSet:(LEGACYSyncSubscriptionSet *)subscriptionSet;

@end

@interface LEGACYSyncSubscriptionSet ()

@property (readonly) uint64_t version;

- (void)addSubscriptionWithClassName:(NSString *)objectClassName
                    subscriptionName:(nullable NSString *)name
                           predicate:(NSPredicate *)predicate
                      updateExisting:(BOOL)updateExisting;

- (void)update:(__attribute__((noescape)) void(^)(void))block
         queue:(nullable dispatch_queue_t)queue
       timeout:(NSTimeInterval)timeout
    onComplete:(void(^)(NSError *))completionBlock;

- (void)waitForSynchronizationOnQueue:(nullable dispatch_queue_t)queue
                              timeout:(NSTimeInterval)timeout
                      completionBlock:(void(^)(NSError *))completionBlock;

- (LEGACYSyncSubscriptionEnumerator *)fastEnumerator;

NSUInteger LEGACYFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            LEGACYSyncSubscriptionSet *collection);

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
