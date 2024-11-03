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

#import <Realm/LEGACYApp_Private.h>

#import <realm/object-store/sync/app.hpp>

#import <memory>

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

LEGACY_DIRECT_MEMBERS
@interface LEGACYAppConfiguration ()
- (const realm::app::App::Config&)config;
- (const realm::SyncClientConfig&)clientConfig;
@end

LEGACY_DIRECT_MEMBERS
@interface LEGACYApp ()
- (std::shared_ptr<realm::app::App>)_realmApp;
@end

NSError *makeError(realm::app::AppError const& appError);

LEGACY_HEADER_AUDIT_END(nullability, sendability)
