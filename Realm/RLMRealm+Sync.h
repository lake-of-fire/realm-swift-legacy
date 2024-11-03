////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
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

#import <Foundation/Foundation.h>

#import <Realm/LEGACYRealm.h>

@class LEGACYResults, LEGACYSyncSession;

LEGACY_HEADER_AUDIT_BEGIN(nullability)

///
@interface LEGACYRealm (Sync)

/**
 Get the LEGACYSyncSession used by this Realm. Will be nil if this is not a
 synchronized Realm.
*/
@property (nonatomic, nullable, readonly) LEGACYSyncSession *syncSession;

@end

LEGACY_HEADER_AUDIT_END(nullability)
