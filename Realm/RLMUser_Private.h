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

#import <Realm/LEGACYUser.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

/// Observer block for user notifications.
typedef void(^LEGACYUserNotificationBlock)(LEGACYUser *);

/// Token that identifies an observer. Unsubscribes when deconstructed to
/// avoid dangling observers, therefore this must be retained to hold
/// onto a subscription.
@interface LEGACYUserSubscriptionToken : NSObject
- (void)unsubscribe;
@end

@interface LEGACYUser ()
/// Subscribe to notifications for this LEGACYUser.
- (LEGACYUserSubscriptionToken *)subscribe:(LEGACYUserNotificationBlock)block;

- (void)logOut;
@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
