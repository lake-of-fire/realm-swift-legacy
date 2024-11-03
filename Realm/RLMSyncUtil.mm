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

#import "LEGACYSyncUtil_Private.hpp"

#import "LEGACYUser_Private.hpp"

NSString *const kLEGACYSyncPathOfRealmBackupCopyKey            = @"recovered_realm_location_path";
NSString *const kLEGACYSyncErrorActionTokenKey                 = @"error_action_token";

#pragma mark - C++ APIs

using namespace realm;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static_assert((int)LEGACYClientResetModeDiscardLocal == (int)realm::ClientResyncMode::DiscardLocal);
#pragma clang diagnostic pop
static_assert((int)LEGACYClientResetModeDiscardUnsyncedChanges == (int)realm::ClientResyncMode::DiscardLocal);
static_assert((int)LEGACYClientResetModeRecoverUnsyncedChanges == (int)realm::ClientResyncMode::Recover);
static_assert((int)LEGACYClientResetModeRecoverOrDiscardUnsyncedChanges == (int)realm::ClientResyncMode::RecoverOrDiscard);
static_assert((int)LEGACYClientResetModeManual == (int)realm::ClientResyncMode::Manual);

static_assert(int(LEGACYSyncStopPolicyImmediately) == int(SyncSessionStopPolicy::Immediately));
static_assert(int(LEGACYSyncStopPolicyLiveIndefinitely) == int(SyncSessionStopPolicy::LiveIndefinitely));
static_assert(int(LEGACYSyncStopPolicyAfterChangesUploaded) == int(SyncSessionStopPolicy::AfterChangesUploaded));

SyncSessionStopPolicy translateStopPolicy(LEGACYSyncStopPolicy stopPolicy) {
    return static_cast<SyncSessionStopPolicy>(stopPolicy);
}

LEGACYSyncStopPolicy translateStopPolicy(SyncSessionStopPolicy stopPolicy) {
    return static_cast<LEGACYSyncStopPolicy>(stopPolicy);
}
