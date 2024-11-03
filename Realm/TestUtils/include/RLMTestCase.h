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

#import <XCTest/XCTest.h>
#import "LEGACYAssertions.h"
#import "LEGACYTestObjects.h"

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

#ifdef __cplusplus
extern "C" {
#endif
NSURL *LEGACYTestRealmURL(void);
NSURL *LEGACYDefaultRealmURL(void);
NSString *LEGACYRealmPathForFile(NSString *);
NSData *LEGACYGenerateKey(void);
#ifdef __cplusplus
}
#endif

@interface LEGACYTestCaseBase : XCTestCase
- (void)resetRealmState;
@end

@interface LEGACYTestCase : LEGACYTestCaseBase

- (LEGACYRealm *)realmWithTestPath;
- (LEGACYRealm *)realmWithTestPathAndSchema:(nullable LEGACYSchema *)schema;

- (LEGACYRealm *)inMemoryRealmWithIdentifier:(NSString *)identifier;
- (LEGACYRealm *)readOnlyRealmWithURL:(NSURL *)fileURL error:(NSError **)error;

- (void)deleteFiles;
- (void)deleteRealmFileAtURL:(NSURL *)fileURL;

- (void)waitForNotification:(LEGACYNotification)expectedNote realm:(LEGACYRealm *)realm block:(dispatch_block_t)block;

- (nullable id)nonLiteralNil;
- (BOOL)encryptTests;

- (void)dispatchAsync:(LEGACY_SWIFT_SENDABLE dispatch_block_t)block;
- (void)dispatchAsyncAndWait:(LEGACY_SWIFT_SENDABLE dispatch_block_t)block;

@property (nonatomic, readonly) dispatch_queue_t bgQueue;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
