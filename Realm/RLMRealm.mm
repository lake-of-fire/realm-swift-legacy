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

#import "LEGACYRealm_Private.hpp"

#import "LEGACYAnalytics.hpp"
#import "LEGACYAsyncTask_Private.h"
#import "LEGACYArray_Private.hpp"
#import "LEGACYDictionary_Private.hpp"
#import "LEGACYError_Private.hpp"
#import "LEGACYLogger.h"
#import "LEGACYMigration_Private.h"
#import "LEGACYObject_Private.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObservation.hpp"
#import "LEGACYProperty.h"
#import "LEGACYProperty_Private.h"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYRealmConfiguration_Private.hpp"
#import "LEGACYRealmUtil.hpp"
#import "LEGACYScheduler.h"
#import "LEGACYSchema_Private.hpp"
#import "LEGACYSyncConfiguration.h"
#import "LEGACYSyncConfiguration_Private.hpp"
#import "LEGACYSet_Private.hpp"
#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUpdateChecker.hpp"
#import "LEGACYUtil.hpp"

#import <realm/disable_sync_to_disk.hpp>
#import <realm/object-store/impl/realm_coordinator.hpp>
#import <realm/object-store/object_store.hpp>
#import <realm/object-store/schema.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/object-store/util/scheduler.hpp>
#import <realm/util/scope_exit.hpp>
#import <realm/version.hpp>

#if REALM_ENABLE_SYNC
#import "LEGACYSyncManager_Private.hpp"
#import "LEGACYSyncSession_Private.hpp"
#import "LEGACYSyncUtil_Private.hpp"
#import "LEGACYSyncSubscription_Private.hpp"

#import <realm/object-store/sync/sync_session.hpp>
#endif

using namespace realm;
using util::File;

@interface LEGACYRealmNotificationToken : LEGACYNotificationToken
@property (nonatomic, strong) LEGACYRealm *realm;
@property (nonatomic, copy) LEGACYNotificationBlock block;
@end

@interface LEGACYRealm ()
@property (nonatomic, strong) NSHashTable<LEGACYRealmNotificationToken *> *notificationHandlers;
- (void)sendNotifications:(LEGACYNotification)notification;
@end

void LEGACYDisableSyncToDisk() {
    realm::disable_sync_to_disk();
}

static std::atomic<bool> s_set_skip_backup_attribute{true};
void LEGACYSetSkipBackupAttribute(bool value) {
    s_set_skip_backup_attribute = value;
}

static void LEGACYAddSkipBackupAttributeToItemAtPath(std::string_view path) {
    [[NSURL fileURLWithPath:@(path.data())] setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
}

void LEGACYWaitForRealmToClose(NSString *path) {
    NSString *lockfilePath = [path stringByAppendingString:@".lock"];
    if (![NSFileManager.defaultManager fileExistsAtPath:lockfilePath]) {
        return;
    }

    File lockfile(lockfilePath.UTF8String, File::mode_Update);
    lockfile.set_fifo_path([path stringByAppendingString:@".management"].UTF8String, "lock.fifo");
    while (!lockfile.try_rw_lock_exclusive()) {
        sched_yield();
    }
}

BOOL LEGACYIsRealmCachedAtPath(NSString *path) {
    return LEGACYGetAnyCachedRealmForPath([path cStringUsingEncoding:NSUTF8StringEncoding]) != nil;
}

LEGACY_HIDDEN
@implementation LEGACYRealmNotificationToken
- (bool)invalidate {
    if (_realm) {
        [_realm verifyThread];
        [_realm.notificationHandlers removeObject:self];
        _realm = nil;
        _block = nil;
        return true;
    }
    return false;
}

- (void)suppressNextNotification {
    // Temporarily replace the block with one which restores the old block
    // rather than producing a notification.

    // This briefly creates a retain cycle but it's fine because the block will
    // be synchronously called shortly after this method is called. Unlike with
    // collection notifications, this does not have to go through the object
    // store or do fancy things to handle transaction coalescing because it's
    // called synchronously by the obj-c code and not by the object store.
    auto notificationBlock = _block;
    _block = ^(LEGACYNotification, LEGACYRealm *) {
        _block = notificationBlock;
    };
}

- (void)dealloc {
    if (_realm || _block) {
        NSLog(@"LEGACYNotificationToken released without unregistering a notification. You must hold "
              @"on to the LEGACYNotificationToken returned from addNotificationBlock and call "
              @"-[LEGACYNotificationToken invalidate] when you no longer wish to receive LEGACYRealm notifications.");
    }
}
@end

static bool shouldForciblyDisableEncryption() {
    static bool disableEncryption = getenv("REALM_DISABLE_ENCRYPTION");
    return disableEncryption;
}

NSData *LEGACYRealmValidatedEncryptionKey(NSData *key) {
    if (shouldForciblyDisableEncryption()) {
        return nil;
    }

    if (key && key.length != 64) {
        @throw LEGACYException(@"Encryption key must be exactly 64 bytes long");
    }

    return key;
}

REALM_NOINLINE void LEGACYRealmTranslateException(NSError **error) {
    try {
        throw;
    }
    catch (FileAccessError const& ex) {
        LEGACYSetErrorOrThrow(makeError(ex), error);
    }
    catch (Exception const& ex) {
        LEGACYSetErrorOrThrow(makeError(ex), error);
    }
    catch (std::system_error const& ex) {
        LEGACYSetErrorOrThrow(makeError(ex), error);
    }
    catch (std::exception const& ex) {
        LEGACYSetErrorOrThrow(makeError(ex), error);
    }
}

namespace {
// ARC tries to eliminate calls to autorelease when the value is then immediately
// returned, but this results in significantly different semantics between debug
// and release builds for LEGACYRealm, so force it to always autorelease.
// NEXT-MAJOR: we should switch to NS_RETURNS_RETAINED, which did not exist yet
// when we wrote this but is the correct thing.
id autorelease(__unsafe_unretained id value) {
    // +1 __bridge_retained, -1 CFAutorelease
    return value ? (__bridge id)CFAutorelease((__bridge_retained CFTypeRef)value) : nil;
}

LEGACYRealm *getCachedRealm(LEGACYRealmConfiguration *configuration, LEGACYScheduler *options) NS_RETURNS_RETAINED {
    auto& config = configuration.configRef;
    if (!configuration.cache && !configuration.dynamic) {
        return nil;
    }

    LEGACYRealm *realm = LEGACYGetCachedRealm(configuration, options);
    if (!realm) {
        return nil;
    }

    auto const& oldConfig = realm->_realm->config();
    if ((oldConfig.read_only() || oldConfig.immutable()) != configuration.readOnly) {
        @throw LEGACYException(@"Realm at path '%@' already opened with different read permissions", configuration.fileURL.path);
    }
    if (oldConfig.in_memory != config.in_memory) {
        @throw LEGACYException(@"Realm at path '%@' already opened with different inMemory settings", configuration.fileURL.path);
    }
    if (realm.dynamic != configuration.dynamic) {
        @throw LEGACYException(@"Realm at path '%@' already opened with different dynamic settings", configuration.fileURL.path);
    }
    if (oldConfig.encryption_key != config.encryption_key) {
        @throw LEGACYException(@"Realm at path '%@' already opened with different encryption key", configuration.fileURL.path);
    }
    return autorelease(realm);
}

bool copySeedFile(LEGACYRealmConfiguration *configuration, NSError **error) {
    if (!configuration.seedFilePath) {
        return false;
    }
    @autoreleasepool {
        bool didCopySeed = false;
        NSError *copyError;
        DB::call_with_lock(configuration.path, [&](auto const&) {
            didCopySeed = [[NSFileManager defaultManager] copyItemAtURL:configuration.seedFilePath
                                                                  toURL:configuration.fileURL
                                                                  error:&copyError];
        });
        if (!didCopySeed && copyError != nil && copyError.code != NSFileWriteFileExistsError) {
            LEGACYSetErrorOrThrow(copyError, error);
            return true;
        }
    }
    return false;
}
} // anonymous namespace

@implementation LEGACYRealm {
    std::mutex _collectionEnumeratorMutex;
    NSHashTable<LEGACYFastEnumerator *> *_collectionEnumerators;
    bool _sendingNotifications;
}

+ (void)initialize {
    // In cases where we are not using a synced Realm, we initialise the default logger
    // before opening any realm.
    [LEGACYLogger class];
}

+ (void)runFirstCheckForConfiguration:(LEGACYRealmConfiguration *)configuration schema:(LEGACYSchema *)schema {
    static bool initialized;
    if (initialized) {
        return;
    }
    initialized = true;

    // Run Analytics on the very first any Realm open.
    LEGACYSendAnalytics(configuration, schema);
    LEGACYCheckForUpdates();
}

- (instancetype)initPrivate {
    self = [super init];
    return self;
}

- (BOOL)isEmpty {
    return realm::ObjectStore::is_empty(self.group);
}

- (void)verifyThread {
    try {
        _realm->verify_thread();
    }
    catch (std::exception const& e) {
        @throw LEGACYException(e);
    }
}

- (BOOL)inWriteTransaction {
    return _realm->is_in_transaction();
}

- (realm::Group &)group {
    return _realm->read_group();
}

- (BOOL)autorefresh {
    return _realm->auto_refresh();
}

- (void)setAutorefresh:(BOOL)autorefresh {
    try {
        _realm->set_auto_refresh(autorefresh);
    }
    catch (std::exception const& e) {
        @throw LEGACYException(e);
    }
}

+ (instancetype)defaultRealm {
    return [LEGACYRealm realmWithConfiguration:[LEGACYRealmConfiguration rawDefaultConfiguration] error:nil];
}

+ (instancetype)defaultRealmForQueue:(dispatch_queue_t)queue {
    return [LEGACYRealm realmWithConfiguration:[LEGACYRealmConfiguration rawDefaultConfiguration]
                                      queue:queue error:nil];
}

+ (instancetype)realmWithURL:(NSURL *)fileURL {
    LEGACYRealmConfiguration *configuration = [LEGACYRealmConfiguration defaultConfiguration];
    configuration.fileURL = fileURL;
    return [LEGACYRealm realmWithConfiguration:configuration error:nil];
}

+ (LEGACYAsyncOpenTask *)asyncOpenWithConfiguration:(LEGACYRealmConfiguration *)configuration
                                   callbackQueue:(dispatch_queue_t)callbackQueue
                                        callback:(LEGACYAsyncOpenRealmCallback)callback {
    return [[LEGACYAsyncOpenTask alloc] initWithConfiguration:configuration
                                                confinedTo:[LEGACYScheduler dispatchQueue:callbackQueue]
                                                  download:true completion:callback];
}

+ (instancetype)realmWithSharedRealm:(SharedRealm)sharedRealm
                              schema:(LEGACYSchema *)schema
                             dynamic:(bool)dynamic {
    LEGACYRealm *realm = [[LEGACYRealm alloc] initPrivate];
    realm->_realm = sharedRealm;
    realm->_dynamic = dynamic;
    realm->_schema = schema;
    if (!dynamic) {
        realm->_realm->set_schema_subset(schema.objectStoreCopy);
    }
    realm->_info = LEGACYSchemaInfo(realm);
    return autorelease(realm);
}

+ (instancetype)realmWithSharedRealm:(std::shared_ptr<Realm>)osRealm
                              schema:(LEGACYSchema *)schema
                             dynamic:(bool)dynamic
                              freeze:(bool)freeze {
    LEGACYRealm *realm = [[LEGACYRealm alloc] initPrivate];
    realm->_realm = osRealm;
    realm->_dynamic = dynamic;

    if (dynamic) {
        realm->_schema = schema ?: [LEGACYSchema dynamicSchemaFromObjectStoreSchema:osRealm->schema()];
    }
    else @autoreleasepool {
        if (auto cachedRealm = LEGACYGetAnyCachedRealmForPath(osRealm->config().path)) {
            realm->_realm->set_schema_subset(cachedRealm->_realm->schema());
            realm->_schema = cachedRealm.schema;
            realm->_info = cachedRealm->_info.clone(cachedRealm->_realm->schema(), realm);
        }
        else if (osRealm->is_frozen()) {
            realm->_schema = schema ?: LEGACYSchema.sharedSchema;
            realm->_realm->set_schema_subset(realm->_schema.objectStoreCopy);
        }
        else {
            realm->_schema = schema ?: LEGACYSchema.sharedSchema;
            try {
                // No migration function: currently this is only used as part of
                // client resets on sync Realms, so none is needed. If that
                // changes, this'll need to as well.
                realm->_realm->update_schema(realm->_schema.objectStoreCopy, osRealm->config().schema_version);
            }
            catch (...) {
                LEGACYRealmTranslateException(nil);
                REALM_COMPILER_HINT_UNREACHABLE();
            }
        }
    }

    if (realm->_info.begin() == realm->_info.end()) {
        realm->_info = LEGACYSchemaInfo(realm);
    }

    if (freeze && !realm->_realm->is_frozen()) {
        realm->_realm = realm->_realm->freeze();
    }

    return realm;
}

+ (instancetype)realmWithConfiguration:(LEGACYRealmConfiguration *)configuration error:(NSError **)error {
    return autorelease([self realmWithConfiguration:configuration
                                         confinedTo:LEGACYScheduler.currentRunLoop
                                              error:error]);
}

+ (instancetype)realmWithConfiguration:(LEGACYRealmConfiguration *)configuration
                                 queue:(dispatch_queue_t)queue
                                 error:(NSError **)error {
    return autorelease([self realmWithConfiguration:configuration
                                         confinedTo:[LEGACYScheduler dispatchQueue:queue]
                                              error:error]);
}

+ (instancetype)realmWithConfiguration:(LEGACYRealmConfiguration *)configuration
                            confinedTo:(LEGACYScheduler *)scheduler
                                 error:(NSError **)error {
    // First check if we already have a cached Realm for this config
    if (auto realm = getCachedRealm(configuration, scheduler)) {
        return realm;
    }

    if (copySeedFile(configuration, error)) {
        return nil;
    }

    bool dynamic = configuration.dynamic;
    bool cache = configuration.cache;

    Realm::Config config = configuration.config;

    LEGACYRealm *realm = [[self alloc] initPrivate];
    realm->_dynamic = dynamic;
    realm->_actor = scheduler.actor;

    // protects the realm cache and accessors cache
    static auto& initLock = *new LEGACYUnfairMutex;
    std::lock_guard lock(initLock);

    try {
        config.scheduler = scheduler.osScheduler;
        if (config.scheduler && !config.scheduler->is_on_thread()) {
            throw LEGACYException(@"Realm opened from incorrect dispatch queue.");
        }
        realm->_realm = Realm::get_shared_realm(config);
    }
    catch (...) {
        LEGACYRealmTranslateException(error);
        return nil;
    }

    bool realmIsCached = false;
    // if we have a cached realm on another thread we can skip a few steps and
    // just grab its schema
    @autoreleasepool {
        // ensure that cachedRealm doesn't end up in this thread's autorelease pool
        if (auto cachedRealm = LEGACYGetAnyCachedRealmForPath(config.path)) {
            realm->_realm->set_schema_subset(cachedRealm->_realm->schema());
            realm->_schema = cachedRealm.schema;
            realm->_info = cachedRealm->_info.clone(cachedRealm->_realm->schema(), realm);
            realmIsCached = true;
        }
    }

    bool isFirstOpen = false;
    if (realm->_schema) { }
    else if (dynamic) {
        realm->_schema = [LEGACYSchema dynamicSchemaFromObjectStoreSchema:realm->_realm->schema()];
        realm->_info = LEGACYSchemaInfo(realm);
    }
    else {
        // set/align schema or perform migration if needed
        LEGACYSchema *schema = configuration.customSchema ?: LEGACYSchema.sharedSchema;

        MigrationFunction migrationFunction;
        auto migrationBlock = configuration.migrationBlock;
        if (migrationBlock && configuration.schemaVersion > 0) {
            migrationFunction = [=](SharedRealm old_realm, SharedRealm realm, Schema& mutableSchema) {
                LEGACYSchema *oldSchema = [LEGACYSchema dynamicSchemaFromObjectStoreSchema:old_realm->schema()];
                LEGACYRealm *oldRealm = [LEGACYRealm realmWithSharedRealm:old_realm
                                                             schema:oldSchema
                                                            dynamic:true];

                // The destination LEGACYRealm can't just use the schema from the
                // SharedRealm because it doesn't have information about whether or
                // not a class was defined in Swift, which effects how new objects
                // are created
                LEGACYRealm *newRealm = [LEGACYRealm realmWithSharedRealm:realm
                                                             schema:schema.copy
                                                            dynamic:true];

                [[[LEGACYMigration alloc] initWithRealm:newRealm oldRealm:oldRealm schema:mutableSchema]
                 execute:migrationBlock objectClass:configuration.migrationObjectClass];

                oldRealm->_realm = nullptr;
                newRealm->_realm = nullptr;
            };
        }

        DataInitializationFunction initializationFunction;
        if (!configuration.rerunOnOpen && configuration.initialSubscriptions) {
            initializationFunction = [&isFirstOpen](SharedRealm) {
                isFirstOpen = true;
            };
        }

        try {
            realm->_realm->update_schema(schema.objectStoreCopy, config.schema_version,
                                         std::move(migrationFunction), std::move(initializationFunction));
        }
        catch (...) {
            LEGACYRealmTranslateException(error);
            return nil;
        }

        realm->_schema = schema;
        realm->_info = LEGACYSchemaInfo(realm);
        LEGACYSchemaEnsureAccessorsCreated(realm.schema);

        if (!configuration.readOnly) {
            REALM_ASSERT(!realm->_realm->is_in_read_transaction());

            if (s_set_skip_backup_attribute) {
                LEGACYAddSkipBackupAttributeToItemAtPath(config.path + ".management");
                LEGACYAddSkipBackupAttributeToItemAtPath(config.path + ".lock");
                LEGACYAddSkipBackupAttributeToItemAtPath(config.path + ".note");
            }
        }
    }

    if (cache) {
        LEGACYCacheRealm(configuration, scheduler, realm);
    }

    if (!configuration.readOnly) {
        realm->_realm->m_binding_context = LEGACYCreateBindingContext(realm);
        realm->_realm->m_binding_context->realm = realm->_realm;
    }

#if REALM_ENABLE_SYNC
    if (isFirstOpen || (configuration.rerunOnOpen && !realmIsCached)) {
        LEGACYSyncSubscriptionSet *subscriptions = realm.subscriptions;
        [subscriptions update:^{
            configuration.initialSubscriptions(subscriptions);
        }];
    }
#endif

    // Run Analytics and Update checker, this will be run only the first any realm open
    [self runFirstCheckForConfiguration:configuration schema:realm.schema];

    return realm;
}

+ (void)resetRealmState {
    LEGACYClearRealmCache();
    realm::_impl::RealmCoordinator::clear_cache();
    [LEGACYRealmConfiguration resetRealmConfigurationState];
}

- (void)verifyNotificationsAreSupported:(bool)isCollection {
    [self verifyThread];
    if (_realm->config().immutable()) {
        @throw LEGACYException(@"Read-only Realms do not change and do not have change notifications.");
    }
    if (_realm->is_frozen()) {
        @throw LEGACYException(@"Frozen Realms do not change and do not have change notifications.");
    }
    if (_realm->config().automatic_change_notifications && !_realm->can_deliver_notifications()) {
        @throw LEGACYException(@"Can only add notification blocks from within runloops.");
    }
}

- (LEGACYNotificationToken *)addNotificationBlock:(LEGACYNotificationBlock)block {
    if (!block) {
        @throw LEGACYException(@"The notification block should not be nil");
    }
    [self verifyNotificationsAreSupported:false];

    _realm->read_group();

    if (!_notificationHandlers) {
        _notificationHandlers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }

    LEGACYRealmNotificationToken *token = [[LEGACYRealmNotificationToken alloc] init];
    token.realm = self;
    token.block = block;
    [_notificationHandlers addObject:token];
    return token;
}

- (void)sendNotifications:(LEGACYNotification)notification {
    NSAssert(!_realm->config().immutable(), @"Read-only realms do not have notifications");
    if (_sendingNotifications) {
        return;
    }
    NSUInteger count = _notificationHandlers.count;
    if (count == 0) {
        return;
    }

    _sendingNotifications = true;
    auto cleanup = realm::util::make_scope_exit([&]() noexcept {
        _sendingNotifications = false;
    });

    // call this realm's notification blocks
    if (count == 1) {
        if (auto block = [_notificationHandlers.anyObject block]) {
            block(notification, self);
        }
    }
    else {
        for (LEGACYRealmNotificationToken *token in _notificationHandlers.allObjects) {
            if (auto block = token.block) {
                block(notification, self);
            }
        }
    }
}

- (LEGACYRealmConfiguration *)configuration {
    LEGACYRealmConfiguration *configuration = [[LEGACYRealmConfiguration alloc] init];
    configuration.configRef = _realm->config();
    configuration.dynamic = _dynamic;
    configuration.customSchema = _schema;
    return configuration;
}

- (void)beginWriteTransaction {
    [self beginWriteTransactionWithError:nil];
}

- (BOOL)beginWriteTransactionWithError:(NSError **)error {
    try {
        _realm->begin_transaction();
        return YES;
    }
    catch (...) {
        LEGACYRealmTranslateException(error);
        return NO;
    }
}

- (void)commitWriteTransaction {
    [self commitWriteTransaction:nil];
}

- (BOOL)commitWriteTransaction:(NSError **)error {
    return [self commitWriteTransactionWithoutNotifying:@[] error:error];
}

- (BOOL)commitWriteTransactionWithoutNotifying:(NSArray<LEGACYNotificationToken *> *)tokens error:(NSError **)error {
    for (LEGACYNotificationToken *token in tokens) {
        if (token.realm != self) {
            @throw LEGACYException(@"Incorrect Realm: only notifications for the Realm being modified can be skipped.");
        }
        [token suppressNextNotification];
    }

    try {
        _realm->commit_transaction();
        return YES;
    }
    catch (...) {
        LEGACYRealmTranslateException(error);
        return NO;
    }
}

- (void)transactionWithBlock:(__attribute__((noescape)) void(^)(void))block {
    [self transactionWithBlock:block error:nil];
}

- (BOOL)transactionWithBlock:(__attribute__((noescape)) void(^)(void))block error:(NSError **)outError {
    return [self transactionWithoutNotifying:@[] block:block error:outError];
}

- (void)transactionWithoutNotifying:(NSArray<LEGACYNotificationToken *> *)tokens block:(__attribute__((noescape)) void(^)(void))block {
    [self transactionWithoutNotifying:tokens block:block error:nil];
}

- (BOOL)transactionWithoutNotifying:(NSArray<LEGACYNotificationToken *> *)tokens block:(__attribute__((noescape)) void(^)(void))block error:(NSError **)error {
    [self beginWriteTransactionWithError:error];
    block();
    if (_realm->is_in_transaction()) {
        return [self commitWriteTransactionWithoutNotifying:tokens error:error];
    }
    return YES;
}

- (void)cancelWriteTransaction {
    try {
        _realm->cancel_transaction();
    }
    catch (std::exception &ex) {
        @throw LEGACYException(ex);
    }
}

- (BOOL)isPerformingAsynchronousWriteOperations {
    return _realm->is_in_async_transaction();
}

- (LEGACYAsyncTransactionId)beginAsyncWriteTransaction:(void(^)())block {
    try {
        return _realm->async_begin_transaction(block);
    }
    catch (std::exception &ex) {
        @throw LEGACYException(ex);
    }
}

- (LEGACYAsyncTransactionId)commitAsyncWriteTransaction {
    try {
        return _realm->async_commit_transaction();
    }
    catch (...) {
        LEGACYRealmTranslateException(nil);
        return 0;
    }
}

- (LEGACYAsyncWriteTask *)beginAsyncWrite {
    try {
        auto write = [[LEGACYAsyncWriteTask alloc] initWithRealm:self];
        write.transactionId = _realm->async_begin_transaction(^{ [write complete:false]; }, true);
        return write;
    }
    catch (std::exception &ex) {
        @throw LEGACYException(ex);
    }
}

- (void)commitAsyncWriteWithGrouping:(bool)allowGrouping
                          completion:(void(^)(NSError *_Nullable))completion {
    [self commitAsyncWriteTransaction:completion allowGrouping:allowGrouping];
}

- (LEGACYAsyncTransactionId)commitAsyncWriteTransaction:(void(^)(NSError *))completionBlock {
    return [self commitAsyncWriteTransaction:completionBlock allowGrouping:false];
}

- (LEGACYAsyncTransactionId)commitAsyncWriteTransaction:(nullable void(^)(NSError *))completionBlock
                                       allowGrouping:(BOOL)allowGrouping {
    try {
        auto completion = [=](std::exception_ptr err) {
            @autoreleasepool {
                if (!completionBlock) {
                    std::rethrow_exception(err);
                    return;
                }
                if (err) {
                    try {
                        std::rethrow_exception(err);
                    }
                    catch (...) {
                        NSError *error;
                        LEGACYRealmTranslateException(&error);
                        completionBlock(error);
                    }
                } else {
                    completionBlock(nil);
                }
            }
        };

        if (completionBlock) {
            return _realm->async_commit_transaction(completion, allowGrouping);
        }
        return _realm->async_commit_transaction(nullptr, allowGrouping);
    }
    catch (...) {
        LEGACYRealmTranslateException(nil);
        return 0;
    }
}

- (void)cancelAsyncTransaction:(LEGACYAsyncTransactionId)asyncTransactionId {
    try {
        _realm->async_cancel_transaction(asyncTransactionId);
    }
    catch (std::exception &ex) {
        @throw LEGACYException(ex);
    }
}

- (LEGACYAsyncTransactionId)asyncTransactionWithBlock:(void(^)())block onComplete:(nullable void(^)(NSError *))completionBlock {
    return [self beginAsyncWriteTransaction:^{
        block();
        if (_realm->is_in_transaction()) {
            [self commitAsyncWriteTransaction:completionBlock];
        }
    }];
}

- (LEGACYAsyncTransactionId)asyncTransactionWithBlock:(void(^)())block {
    return [self beginAsyncWriteTransaction:^{
        block();
        if (_realm->is_in_transaction()) {
            [self commitAsyncWriteTransaction];
        }
    }];
}

- (void)invalidate {
    if (_realm->is_in_transaction()) {
        NSLog(@"WARNING: An LEGACYRealm instance was invalidated during a write "
              "transaction and all pending changes have been rolled back.");
    }

    [self detachAllEnumerators];

    for (auto& objectInfo : _info) {
        for (LEGACYObservationInfo *info : objectInfo.second.observedObjects) {
            info->willChange(LEGACYInvalidatedKey);
        }
    }

    _realm->invalidate();

    for (auto& objectInfo : _info) {
        for (LEGACYObservationInfo *info : objectInfo.second.observedObjects) {
            info->didChange(LEGACYInvalidatedKey);
        }
    }

    if (_realm->is_frozen()) {
        _realm->close();
    }
}

- (nullable id)resolveThreadSafeReference:(LEGACYThreadSafeReference *)reference {
    return [reference resolveReferenceInRealm:self];
}

/**
 Replaces all string columns in this Realm with a string enumeration column and compacts the
 database file.

 Cannot be called from a write transaction.

 Compaction will not occur if other `LEGACYRealm` instances exist.

 While compaction is in progress, attempts by other threads or processes to open the database will
 wait.

 Be warned that resource requirements for compaction is proportional to the amount of live data in
 the database.

 Compaction works by writing the database contents to a temporary database file and then replacing
 the database with the temporary one. The name of the temporary file is formed by appending
 `.tmp_compaction_space` to the name of the database.

 @return YES if the compaction succeeded.
 */
- (BOOL)compact {
    // compact() automatically ends the read transaction, but we need to clean
    // up cached state and send invalidated notifications when that happens, so
    // explicitly end it first unless we're in a write transaction (in which
    // case compact() will throw an exception)
    if (!_realm->is_in_transaction()) {
        [self invalidate];
    }

    try {
        return _realm->compact();
    }
    catch (std::exception const& ex) {
        @throw LEGACYException(ex);
    }
}

- (void)dealloc {
    if (_realm) {
        if (_realm->is_in_transaction()) {
            [self cancelWriteTransaction];
            NSLog(@"WARNING: An LEGACYRealm instance was deallocated during a write transaction and all "
                  "pending changes have been rolled back. Make sure to retain a reference to the "
                  "LEGACYRealm for the duration of the write transaction.");
        }
    }
}

- (BOOL)refresh {
    if (_realm->config().immutable()) {
        @throw LEGACYException(@"Read-only Realms do not change and cannot be refreshed.");
    }
    try {
        return _realm->refresh();
    }
    catch (std::exception const& e) {
        @throw LEGACYException(e);
    }
}

- (void)addObject:(__unsafe_unretained LEGACYObject *const)object {
    LEGACYAddObjectToRealm(object, self, LEGACYUpdatePolicyError);
}

- (void)addObjects:(id<NSFastEnumeration>)objects {
    for (LEGACYObject *obj in objects) {
        if (![obj isKindOfClass:LEGACYObjectBase.class]) {
            @throw LEGACYException(@"Cannot insert objects of type %@ with addObjects:. Only LEGACYObjects are supported.",
                                NSStringFromClass(obj.class));
        }
        [self addObject:obj];
    }
}

- (void)addOrUpdateObject:(LEGACYObject *)object {
    // verify primary key
    if (!object.objectSchema.primaryKeyProperty) {
        @throw LEGACYException(@"'%@' does not have a primary key and can not be updated", object.objectSchema.className);
    }

    LEGACYAddObjectToRealm(object, self, LEGACYUpdatePolicyUpdateAll);
}

- (void)addOrUpdateObjects:(id<NSFastEnumeration>)objects {
    for (LEGACYObject *obj in objects) {
        if (![obj isKindOfClass:LEGACYObjectBase.class]) {
            @throw LEGACYException(@"Cannot add or update objects of type %@ with addOrUpdateObjects:. Only LEGACYObjects are"
                                " supported.",
                                NSStringFromClass(obj.class));
        }
        [self addOrUpdateObject:obj];
    }
}

- (void)deleteObject:(LEGACYObject *)object {
    LEGACYDeleteObjectFromRealm(object, self);
}

- (void)deleteObjects:(id<NSFastEnumeration>)objects {
    id idObjects = objects;
    if ([idObjects respondsToSelector:@selector(realm)]
        && [idObjects respondsToSelector:@selector(deleteObjectsFromRealm)]) {
        if (self != (LEGACYRealm *)[idObjects realm]) {
            @throw LEGACYException(@"Can only delete objects from the Realm they belong to.");
        }
        [idObjects deleteObjectsFromRealm];
        return;
    }

    if (auto array = LEGACYDynamicCast<LEGACYArray>(objects)) {
        if (array.type != LEGACYPropertyTypeObject) {
            @throw LEGACYException(@"Cannot delete objects from LEGACYArray<%@>: only LEGACYObjects can be deleted.",
                                LEGACYTypeToString(array.type));
        }
    }
    else if (auto set = LEGACYDynamicCast<LEGACYSet>(objects)) {
        if (set.type != LEGACYPropertyTypeObject) {
            @throw LEGACYException(@"Cannot delete objects from LEGACYSet<%@>: only LEGACYObjects can be deleted.",
                                LEGACYTypeToString(set.type));
        }
    }
    else if (auto dictionary = LEGACYDynamicCast<LEGACYDictionary>(objects)) {
        if (dictionary.type != LEGACYPropertyTypeObject) {
            @throw LEGACYException(@"Cannot delete objects from LEGACYDictionary of type %@: only LEGACYObjects can be deleted.",
                                LEGACYTypeToString(dictionary.type));
        }
        for (LEGACYObject *obj in dictionary.allValues) {
            LEGACYDeleteObjectFromRealm(obj, self);
        }
        return;
    }
    for (LEGACYObject *obj in objects) {
        if (![obj isKindOfClass:LEGACYObjectBase.class]) {
            @throw LEGACYException(@"Cannot delete objects of type %@ with deleteObjects:. Only LEGACYObjects can be deleted.",
                                NSStringFromClass(obj.class));
        }
        LEGACYDeleteObjectFromRealm(obj, self);
    }
}

- (void)deleteAllObjects {
    LEGACYDeleteAllObjectsFromRealm(self);
}

- (LEGACYResults *)allObjects:(NSString *)objectClassName {
    return LEGACYGetObjects(self, objectClassName, nil);
}

- (LEGACYResults *)objects:(NSString *)objectClassName where:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    LEGACYResults *results = [self objects:objectClassName where:predicateFormat args:args];
    va_end(args);
    return results;
}

- (LEGACYResults *)objects:(NSString *)objectClassName where:(NSString *)predicateFormat args:(va_list)args {
    return [self objects:objectClassName withPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (LEGACYResults *)objects:(NSString *)objectClassName withPredicate:(NSPredicate *)predicate {
    return LEGACYGetObjects(self, objectClassName, predicate);
}

- (LEGACYObject *)objectWithClassName:(NSString *)className forPrimaryKey:(id)primaryKey {
    return LEGACYGetObject(self, className, primaryKey);
}

+ (uint64_t)schemaVersionAtURL:(NSURL *)fileURL encryptionKey:(NSData *)key error:(NSError **)error {
    LEGACYRealmConfiguration *config = [[LEGACYRealmConfiguration alloc] init];
    config.fileURL = fileURL;
    config.encryptionKey = LEGACYRealmValidatedEncryptionKey(key);

    uint64_t version = LEGACYNotVersioned;
    try {
        version = Realm::get_schema_version(config.configRef);
    }
    catch (...) {
        LEGACYRealmTranslateException(error);
        return version;
    }

    if (error && version == realm::ObjectStore::NotVersioned) {
        auto msg = [NSString stringWithFormat:@"Realm at path '%@' has not been initialized.", fileURL.path];
        *error = [NSError errorWithDomain:LEGACYErrorDomain
                                     code:LEGACYErrorInvalidDatabase
                                 userInfo:@{NSLocalizedDescriptionKey: msg,
                                            NSFilePathErrorKey: fileURL.path}];
    }
    return version;
}

+ (BOOL)performMigrationForConfiguration:(LEGACYRealmConfiguration *)configuration error:(NSError **)error {
    if (LEGACYGetAnyCachedRealmForPath(configuration.path)) {
        @throw LEGACYException(@"Cannot migrate Realms that are already open.");
    }

    NSError *localError; // Prevents autorelease
    BOOL success;
    @autoreleasepool {
        success = [LEGACYRealm realmWithConfiguration:configuration error:&localError] != nil;
    }
    if (!success && error) {
        *error = localError; // Must set outside pool otherwise will free anyway
    }
    return success;
}

- (LEGACYObject *)createObject:(NSString *)className withValue:(id)value {
    return (LEGACYObject *)LEGACYCreateObjectInRealmWithValue(self, className, value, LEGACYUpdatePolicyError);
}

- (BOOL)writeCopyToURL:(NSURL *)fileURL encryptionKey:(NSData *)key error:(NSError **)error {
    LEGACYRealmConfiguration *configuration = [LEGACYRealmConfiguration new];
    configuration.fileURL = fileURL;
    configuration.encryptionKey = key;
    return [self writeCopyForConfiguration:configuration error:error];
}

- (BOOL)writeCopyForConfiguration:(LEGACYRealmConfiguration *)configuration error:(NSError **)error {
    try {
        _realm->convert(configuration.configRef, false);
        return YES;
    }
    catch (...) {
        if (error) {
            LEGACYRealmTranslateException(error);
        }
    }
    return NO;
}

+ (BOOL)fileExistsForConfiguration:(LEGACYRealmConfiguration *)config {
    return [NSFileManager.defaultManager fileExistsAtPath:config.pathOnDisk];
}

+ (BOOL)deleteFilesForConfiguration:(LEGACYRealmConfiguration *)config error:(NSError **)error {
    bool didDeleteAny = false;
    try {
        realm::Realm::delete_files(config.path, &didDeleteAny);
    }
    catch (realm::FileAccessError const& e) {
        if (error) {
            // For backwards compatibility, but this should go away in 11.0
            if (e.code() == realm::ErrorCodes::PermissionDenied) {
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError
                                         userInfo:@{NSLocalizedDescriptionKey: @(e.what()),
                                                    NSFilePathErrorKey: @(e.get_path().data())}];
            }
            else {
                LEGACYRealmTranslateException(error);
            }
        }
    }
    catch (...) {
        if (error) {
            LEGACYRealmTranslateException(error);
        }
    }
    return didDeleteAny;
}

- (BOOL)isFrozen {
    return _realm->is_frozen();
}

- (LEGACYRealm *)freeze {
    [self verifyThread];
    return self.isFrozen ? self : LEGACYGetFrozenRealmForSourceRealm(self);
}

- (LEGACYRealm *)thaw {
    [self verifyThread];
    return self.isFrozen ? [LEGACYRealm realmWithConfiguration:self.configuration error:nil] : self;
}

- (LEGACYRealm *)frozenCopy {
    try {
        LEGACYRealm *realm = [[LEGACYRealm alloc] initPrivate];
        realm->_realm = _realm->freeze();
        realm->_realm->read_group();
        realm->_dynamic = _dynamic;
        realm->_schema = _schema;
        realm->_info = LEGACYSchemaInfo(realm);
        return realm;
    }
    catch (std::exception const& e) {
        @throw LEGACYException(e);
    }
}

- (void)registerEnumerator:(LEGACYFastEnumerator *)enumerator {
    std::lock_guard lock(_collectionEnumeratorMutex);
    if (!_collectionEnumerators) {
        _collectionEnumerators = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    [_collectionEnumerators addObject:enumerator];
}

- (void)unregisterEnumerator:(LEGACYFastEnumerator *)enumerator {
    std::lock_guard lock(_collectionEnumeratorMutex);
    [_collectionEnumerators removeObject:enumerator];
}

- (void)detachAllEnumerators {
    std::lock_guard lock(_collectionEnumeratorMutex);
    for (LEGACYFastEnumerator *enumerator in _collectionEnumerators) {
        [enumerator detach];
    }
    _collectionEnumerators = nil;
}

- (bool)isFlexibleSync {
#if REALM_ENABLE_SYNC
    return _realm->config().sync_config && _realm->config().sync_config->flx_sync_requested;
#else
    return false;
#endif
}

- (LEGACYSyncSubscriptionSet *)subscriptions {
#if REALM_ENABLE_SYNC
    if (!self.isFlexibleSync) {
        @throw LEGACYException(@"This Realm was not configured with flexible sync");
    }
    return [[LEGACYSyncSubscriptionSet alloc] initWithSubscriptionSet:_realm->get_latest_subscription_set() realm:self];
#else
    @throw LEGACYException(@"Realm was not compiled with sync enabled");
#endif
}

void LEGACYRealmSubscribeToAll(LEGACYRealm *realm) {
    if (!realm.isFlexibleSync) {
        return;
    }

    auto subs = realm->_realm->get_latest_subscription_set().make_mutable_copy();
    auto& group = realm->_realm->read_group();
    for (auto key : group.get_table_keys()) {
        if (!std::string_view(group.get_table_name(key)).starts_with("class_")) {
            continue;
        }
        subs.insert_or_assign(group.get_table(key)->where());
    }
    subs.commit();
}
@end
