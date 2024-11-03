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

#import <Realm/LEGACYApp.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

/// Observer block for app notifications.
typedef void(^LEGACYAppNotificationBlock)(LEGACYApp *);

/// Token that identifies an observer. Unsubscribes when deconstructed to
/// avoid dangling observers, therefore this must be retained to hold
/// onto a subscription.
@interface LEGACYAppSubscriptionToken : NSObject
- (void)unsubscribe;
@end

@interface LEGACYApp ()
/// Returns all currently cached Apps
+ (NSArray<LEGACYApp *> *)allApps;
/// Subscribe to notifications for this LEGACYApp.
- (LEGACYAppSubscriptionToken *)subscribe:(LEGACYAppNotificationBlock)block;

+ (instancetype)appWithConfiguration:(LEGACYAppConfiguration *)configuration;

+ (void)resetAppCache;
@end

@interface LEGACYAppConfiguration ()
@property (nonatomic) NSString *appId;
@property (nonatomic) BOOL encryptMetadata;
@property (nonatomic) NSURL *rootDirectory;
@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
