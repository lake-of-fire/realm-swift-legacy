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

#import "LEGACYTestCase.h"

#import "LEGACYRealmConfiguration_Private.h"
#import <Realm/LEGACYRealm_Private.h>
#import <Realm/LEGACYSchema_Private.h>
#import <Realm/LEGACYRealmConfiguration_Private.h>

static NSString *parentProcessBundleIdentifier(void)
{
    static BOOL hasInitializedIdentifier;
    static NSString *identifier;
    if (!hasInitializedIdentifier) {
        identifier = [NSProcessInfo processInfo].environment[@"LEGACYParentProcessBundleID"];
        hasInitializedIdentifier = YES;
    }

    return identifier;
}

NSURL *LEGACYDefaultRealmURL(void) {
    return [NSURL fileURLWithPath:LEGACYRealmPathForFileAndBundleIdentifier(@"default.realm", parentProcessBundleIdentifier())];
}

NSURL *LEGACYTestRealmURL(void) {
    return [NSURL fileURLWithPath:LEGACYRealmPathForFileAndBundleIdentifier(@"test.realm", parentProcessBundleIdentifier())];
}

static void deleteOrThrow(NSURL *fileURL) {
    NSError *error;
    if (![[NSFileManager defaultManager] removeItemAtURL:fileURL error:&error]) {
        if (error.code != NSFileNoSuchFileError) {
            @throw [NSException exceptionWithName:@"LEGACYTestException"
                                           reason:[@"Unable to delete realm: " stringByAppendingString:error.description]
                                         userInfo:nil];
        }
    }
}

NSData *LEGACYGenerateKey(void) {
    uint8_t buffer[64];
    (void)SecRandomCopyBytes(kSecRandomDefault, 64, buffer);
    return [[NSData alloc] initWithBytes:buffer length:sizeof(buffer)];
}

static BOOL encryptTests(void) {
    static BOOL encryptAll = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *str = getenv("REALM_ENCRYPT_ALL");
        if (str && *str) {
            encryptAll = YES;
        }
    });
    return encryptAll;
}

@implementation LEGACYTestCaseBase
+ (void)setUp {
    [super setUp];
#if DEBUG || !TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    // Disable actually syncing anything to the disk to greatly speed up the
    // tests, but only when not running on device because it can't be
    // re-enabled and we need it enabled for performance tests
    LEGACYDisableSyncToDisk();
#endif
    // Don't bother disabling backups on our non-Realm files because it takes
    // a while and we're going to delete them anyway.
    LEGACYSetSkipBackupAttribute(false);

    if (!getenv("LEGACYProcessIsChild")) {
        [self preinitializeSchema];

        // Clean up any potentially lingering Realm files from previous runs
        [NSFileManager.defaultManager removeItemAtPath:LEGACYRealmPathForFile(@"") error:nil];
    }

    // Ensure the documents directory exists as it sometimes doesn't after
    // resetting the simulator
    [NSFileManager.defaultManager createDirectoryAtURL:LEGACYDefaultRealmURL().URLByDeletingLastPathComponent
                           withIntermediateDirectories:YES attributes:nil error:nil];
}

// This ensures the shared schema is initialized outside of of a test case,
// so if an exception is thrown, it will kill the test process rather than
// allowing hundreds of test cases to fail in strange ways
// This is overridden by LEGACYMultiProcessTestCase to support testing the schema init
+ (void)preinitializeSchema {
    [LEGACYSchema sharedSchema];
}

// A hook point for subclasses to override the cleanup
- (void)resetRealmState {
    [LEGACYRealm resetRealmState];
}
@end

@implementation LEGACYTestCase {
    dispatch_queue_t _bgQueue;
}

- (void)deleteFiles {
    // Clear cache
    [self resetRealmState];

    // Delete Realm files
    NSURL *directory = LEGACYDefaultRealmURL().URLByDeletingLastPathComponent;
    NSError *error = nil;
    for (NSString *file in [NSFileManager.defaultManager
                            contentsOfDirectoryAtPath:directory.path error:&error]) {
        deleteOrThrow([directory URLByAppendingPathComponent:file]);
    }
}

- (void)deleteRealmFileAtURL:(NSURL *)fileURL {
    deleteOrThrow(fileURL);
    deleteOrThrow([fileURL URLByAppendingPathExtension:@"lock"]);
    deleteOrThrow([fileURL URLByAppendingPathExtension:@"note"]);
}

- (BOOL)encryptTests {
    return encryptTests();
}

- (void)invokeTest {
    @autoreleasepool {
        [self deleteFiles];

        if (self.encryptTests) {
            LEGACYRealmConfiguration *configuration = [LEGACYRealmConfiguration rawDefaultConfiguration];
            configuration.encryptionKey = LEGACYGenerateKey();
        }
    }
    @autoreleasepool {
        [super invokeTest];
    }
    @autoreleasepool {
        if (_bgQueue) {
            dispatch_sync(_bgQueue, ^{});
            _bgQueue = nil;
        }
        [self deleteFiles];
    }
}

- (LEGACYRealm *)realmWithTestPath {
    return [LEGACYRealm realmWithURL:LEGACYTestRealmURL()];
}

- (LEGACYRealm *)realmWithTestPathAndSchema:(LEGACYSchema *)schema {
    LEGACYRealmConfiguration *configuration = [LEGACYRealmConfiguration defaultConfiguration];
    configuration.fileURL = LEGACYTestRealmURL();
    if (schema)
        configuration.customSchema = schema;
    else
        configuration.dynamic = true;
    return [LEGACYRealm realmWithConfiguration:configuration error:nil];
}

- (LEGACYRealm *)inMemoryRealmWithIdentifier:(NSString *)identifier {
    LEGACYRealmConfiguration *configuration = [LEGACYRealmConfiguration defaultConfiguration];
    configuration.encryptionKey = nil;
    configuration.inMemoryIdentifier = identifier;
    return [LEGACYRealm realmWithConfiguration:configuration error:nil];
}

- (LEGACYRealm *)readOnlyRealmWithURL:(NSURL *)fileURL error:(NSError **)error {
    LEGACYRealmConfiguration *configuration = [LEGACYRealmConfiguration defaultConfiguration];
    configuration.fileURL = fileURL;
    configuration.readOnly = true;
    return [LEGACYRealm realmWithConfiguration:configuration error:error];
}

- (void)waitForNotification:(NSString *)expectedNote realm:(LEGACYRealm *)realm block:(dispatch_block_t)block {
    XCTestExpectation *notificationFired = [self expectationWithDescription:@"notification fired"];
    __block LEGACYNotificationToken *token = [realm addNotificationBlock:^(NSString *note, LEGACYRealm *realm) {
        XCTAssertNotNil(note, @"Note should not be nil");
        XCTAssertNotNil(realm, @"Realm should not be nil");
        if (note == expectedNote) { // Check pointer equality to ensure we're using the interned string constant
            [notificationFired fulfill];
            [token invalidate];
        }
    }];

    dispatch_queue_t queue = dispatch_queue_create("background", 0);
    dispatch_async(queue, ^{
        @autoreleasepool {
            block();
        }
    });

    [self waitForExpectationsWithTimeout:30.0 handler:nil];

    // wait for queue to finish
    dispatch_sync(queue, ^{});
}

- (dispatch_queue_t)bgQueue {
    if (!_bgQueue) {
        _bgQueue = dispatch_queue_create("test background queue", 0);
    }
    return _bgQueue;
}

- (void)dispatchAsync:(LEGACY_SWIFT_SENDABLE dispatch_block_t)block {
    dispatch_async(self.bgQueue, ^{
        @autoreleasepool {
            block();
        }
    });
}

- (void)dispatchAsyncAndWait:(LEGACY_SWIFT_SENDABLE dispatch_block_t)block {
    [self dispatchAsync:block];
    dispatch_sync(_bgQueue, ^{});
}

- (id)nonLiteralNil {
    return nil;
}

@end

