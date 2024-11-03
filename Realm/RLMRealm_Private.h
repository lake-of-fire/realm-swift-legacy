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

#import <Realm/LEGACYRealm.h>

@class LEGACYFastEnumerator, LEGACYScheduler, LEGACYAsyncRefreshTask, LEGACYAsyncWriteTask;

LEGACY_HEADER_AUDIT_BEGIN(nullability)

// Disable syncing files to disk. Cannot be re-enabled. Use only for tests.
FOUNDATION_EXTERN void LEGACYDisableSyncToDisk(void);
// Set whether the skip backup attribute should be set on temporary files.
FOUNDATION_EXTERN void LEGACYSetSkipBackupAttribute(bool value);

FOUNDATION_EXTERN NSData * _Nullable LEGACYRealmValidatedEncryptionKey(NSData *key);

// Set the queue used for async open. For testing purposes only.
FOUNDATION_EXTERN void LEGACYSetAsyncOpenQueue(dispatch_queue_t queue);

// Translate an in-flight exception resulting from an operation on a SharedGroup to
// an NSError or NSException (if error is nil)
void LEGACYRealmTranslateException(NSError **error);

// Block until the Realm at the given path is closed.
FOUNDATION_EXTERN void LEGACYWaitForRealmToClose(NSString *path);
BOOL LEGACYIsRealmCachedAtPath(NSString *path);

// Register a block to be called from the next before_notify() invocation
FOUNDATION_EXTERN void LEGACYAddBeforeNotifyBlock(LEGACYRealm *realm, dispatch_block_t block);

// Test hook to run the async notifiers for a Realm which has the background thread disabled
FOUNDATION_EXTERN void LEGACYRunAsyncNotifiers(NSString *path);

// Get the cached Realm for the given configuration and scheduler, if any
FOUNDATION_EXTERN LEGACYRealm *_Nullable LEGACYGetCachedRealm(LEGACYRealmConfiguration *, LEGACYScheduler *) NS_RETURNS_RETAINED;
// Get a cached Realm for the given configuration and any scheduler. The returned
// Realm is not confined to the current thread, so very few operations are safe
// to perform on it
FOUNDATION_EXTERN LEGACYRealm *_Nullable LEGACYGetAnyCachedRealm(LEGACYRealmConfiguration *) NS_RETURNS_RETAINED;

// Scheduler an async refresh for the given Realm
FOUNDATION_EXTERN LEGACYAsyncRefreshTask *_Nullable LEGACYRealmRefreshAsync(LEGACYRealm *rlmRealm) NS_RETURNS_RETAINED;

FOUNDATION_EXTERN void LEGACYRealmSubscribeToAll(LEGACYRealm *);

// LEGACYRealm private members
@interface LEGACYRealm ()
@property (nonatomic, readonly) BOOL dynamic;
@property (nonatomic, readwrite) LEGACYSchema *schema;
@property (nonatomic, readonly, nullable) id actor;
@property (nonatomic, readonly) bool isFlexibleSync;

+ (void)resetRealmState;

- (void)registerEnumerator:(LEGACYFastEnumerator *)enumerator;
- (void)unregisterEnumerator:(LEGACYFastEnumerator *)enumerator;
- (void)detachAllEnumerators;

- (void)sendNotifications:(LEGACYNotification)notification;
- (void)verifyThread;
- (void)verifyNotificationsAreSupported:(bool)isCollection;

- (LEGACYRealm *)frozenCopy NS_RETURNS_RETAINED;

+ (nullable instancetype)realmWithConfiguration:(LEGACYRealmConfiguration *)configuration
                                     confinedTo:(LEGACYScheduler *)options
                                          error:(NSError **)error;

- (LEGACYAsyncWriteTask *)beginAsyncWrite NS_RETURNS_RETAINED;
- (void)commitAsyncWriteWithGrouping:(bool)allowGrouping
                          completion:(void(^)(NSError *_Nullable))completion;
@end

@interface LEGACYPinnedRealm : NSObject
@property (nonatomic, readonly) LEGACYRealmConfiguration *configuration;

- (instancetype)initWithRealm:(LEGACYRealm *)realm;
- (void)unpin;
@end

LEGACY_HEADER_AUDIT_END(nullability)
