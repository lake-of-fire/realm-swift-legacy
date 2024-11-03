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

#import <Realm/LEGACYConstants.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@class LEGACYApp;

/// Base provider client interface.
LEGACY_SWIFT_SENDABLE
@interface LEGACYProviderClient : NSObject

/// The app associated with this provider client.
@property (nonatomic, strong, readonly) LEGACYApp *app;

/**
 Initialize a provider client with a given app.
 @param app The app for this provider client.
 */
- (instancetype)initWithApp:(LEGACYApp *)app;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
