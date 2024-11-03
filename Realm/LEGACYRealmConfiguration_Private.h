////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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

#import <Realm/LEGACYRealmConfiguration.h>

@class LEGACYSchema, LEGACYEventConfiguration;

LEGACY_HEADER_AUDIT_BEGIN(nullability)

@interface LEGACYRealmConfiguration ()

@property (nonatomic, readwrite) bool cache;
@property (nonatomic, readwrite) bool dynamic;
@property (nonatomic, readwrite) bool disableFormatUpgrade;
@property (nonatomic, copy, nullable) LEGACYSchema *customSchema;
@property (nonatomic, copy) NSString *pathOnDisk;
@property (nonatomic, retain, nullable) LEGACYEventConfiguration *eventConfiguration;
@property (nonatomic, nullable) Class migrationObjectClass;
@property (nonatomic) bool disableAutomaticChangeNotifications;

// Flexible Sync
@property (nonatomic, readwrite, nullable) LEGACYFlexibleSyncInitialSubscriptionsBlock initialSubscriptions;
@property (nonatomic, readwrite) BOOL rerunOnOpen;

// Get the default configuration without copying it
+ (LEGACYRealmConfiguration *)rawDefaultConfiguration;

+ (void)resetRealmConfigurationState;

- (void)setCustomSchemaWithoutCopying:(nullable LEGACYSchema *)schema;
@end

// Get a path in the platform-appropriate documents directory with the given filename
FOUNDATION_EXTERN NSString *LEGACYRealmPathForFile(NSString *fileName);
FOUNDATION_EXTERN NSString *LEGACYRealmPathForFileAndBundleIdentifier(NSString *fileName, NSString *mainBundleIdentifier);

LEGACY_HEADER_AUDIT_END(nullability)
