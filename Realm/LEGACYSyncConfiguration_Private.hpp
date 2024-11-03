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

#import "LEGACYSyncConfiguration_Private.h"

#import <memory>

namespace realm {
class SyncSession;
struct SyncConfig;
struct SyncError;
using SyncSessionErrorHandler = void(std::shared_ptr<SyncSession>, SyncError);
}

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface LEGACYSyncConfiguration ()
- (instancetype)initWithRawConfig:(realm::SyncConfig)config path:(std::string const&)path;
- (realm::SyncConfig&)rawConfiguration;

// Pass the LEGACYRealmConfiguration to it's sync configuration so client reset callbacks
// can access schema, dynamic, and path properties.
void LEGACYSetConfigInfoForClientResetCallbacks(realm::SyncConfig& syncConfig, LEGACYRealmConfiguration *config);

@property (nonatomic, direct) std::string path;
@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
