////////////////////////////////////////////////////////////////////////////
//
// Copyright 2022 Realm Inc.
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

@protocol LEGACYValue;

#pragma mark - Error Domains

/** Error code is a value from the LEGACYError enum. */
extern NSString *const LEGACYErrorDomain;

/** An error domain identifying non-specific system errors. */
extern NSString *const LEGACYUnknownSystemErrorDomain;

/**
 The error domain string for all SDK errors related to errors reported
 by the synchronization manager error handler, as well as general sync
 errors that don't fall into any of the other categories.
 */
extern NSString *const LEGACYSyncErrorDomain;

/**
 The error domain string for all SDK errors related to the authentication
 endpoint.
 */
extern NSString *const LEGACYSyncAuthErrorDomain;

/**
The error domain string for all SDK errors related to the Atlas App Services
endpoint.
*/
extern NSString *const LEGACYAppErrorDomain;

#pragma mark - LEGACYError

/// A user info key containing the error code. This is provided for backwards
/// compatibility only and should not be used.
extern NSString *const LEGACYErrorCodeKey __attribute((deprecated("use -[NSError code]")));

/// A user info key containing the name of the error code. This is for
/// debugging purposes only and should not be relied on.
extern NSString *const LEGACYErrorCodeNameKey;

/// A user info key present in sync errors which originate from the server,
/// containing the URL of the server-side logs associated with the error.
extern NSString * const LEGACYServerLogURLKey;

/// A user info key containing a HTTP status code. Some ``LEGACYAppError`` codes
/// include this, most notably ``LEGACYAppErrorHttpRequestFailed``.
extern NSString * const LEGACYHTTPStatusCodeKey;

/// A user info key containing a `LEGACYCompensatingWriteInfo` which includes
/// further details about what was reverted by the server.
extern NSString *const LEGACYCompensatingWriteInfoKey;

/**
 `LEGACYError` is an enumeration representing all recoverable errors. It is
 associated with the Realm error domain specified in `LEGACYErrorDomain`.
 */
typedef LEGACY_ERROR_ENUM(NSInteger, LEGACYError, LEGACYErrorDomain) {
    /** Denotes a general error that occurred when trying to open a Realm. */
    LEGACYErrorFail                  = 1,

    /** Denotes a file I/O error that occurred when trying to open a Realm. */
    LEGACYErrorFileAccess            = 2,

    /**
     Denotes a file permission error that occurred when trying to open a Realm.

     This error can occur if the user does not have permission to open or create
     the specified file in the specified access mode when opening a Realm.
     */
    LEGACYErrorFilePermissionDenied  = 3,

    /**
     Denotes an error where a file was to be written to disk, but another
     file with the same name already exists.
     */
    LEGACYErrorFileExists            = 4,

    /**
     Denotes an error that occurs if a file could not be found.

     This error may occur if a Realm file could not be found on disk when
     trying to open a Realm as read-only, or if the directory part of the
     specified path was not found when trying to write a copy.
     */
    LEGACYErrorFileNotFound          = 5,

    /**
     Denotes an error that occurs if a file format upgrade is required to open
     the file, but upgrades were explicitly disabled or the file is being open
     in read-only mode.
     */
    LEGACYErrorFileFormatUpgradeRequired = 6,

    /**
     Denotes an error that occurs if the database file is currently open in
     another process which cannot share with the current process due to an
     architecture mismatch.

     This error may occur if trying to share a Realm file between an i386
     (32-bit) iOS Simulator and the Realm Studio application. In this case,
     please use the 64-bit version of the iOS Simulator.
     */
    LEGACYErrorIncompatibleLockFile  = 8,

    /**
     Denotes an error that occurs when there is insufficient available address
     space to mmap the Realm file.
     */
    LEGACYErrorAddressSpaceExhausted = 9,

    /**
    Denotes an error that occurs if there is a schema version mismatch and a
    migration is required.
    */
    LEGACYErrorSchemaMismatch = 10,

    /**
     Denotes an error where an operation was requested which cannot be
     performed on an open file.
     */
    LEGACYErrorAlreadyOpen = 12,

    /// Denotes an error where an input value was invalid.
    LEGACYErrorInvalidInput = 13,

    /// Denotes an error where a write failed due to insufficient disk space.
    LEGACYErrorOutOfDiskSpace = 14,

    /**
     Denotes an error where a Realm file could not be opened because another
     process has opened the same file in a way incompatible with inter-process
     sharing. For example, this can result from opening the backing file for an
     in-memory Realm in non-in-memory mode.
     */
    LEGACYErrorIncompatibleSession = 15,

    /**
     Denotes an error that occurs if the file is a valid Realm file, but has a
     file format version which is not supported by this version of Realm. This
     typically means that the file was written by a newer version of Realm, but
     may also mean that it is from a pre-1.0 version of Realm (or for
     synchronized files, pre-10.0).
     */
    LEGACYErrorUnsupportedFileFormatVersion = 16,

    /**
     Denotes an error that occurs if a synchronized Realm is opened in more
     than one process at once.
     */
    LEGACYErrorMultipleSyncAgents = 17,

    /// A subscription was rejected by the server.
    LEGACYErrorSubscriptionFailed = 18,

    /// A file operation failed in a way which does not have a more specific error code.
    LEGACYErrorFileOperationFailed = 19,

    /**
     Denotes an error that occurs if the file being opened is not a valid Realm
     file. Some of the possible causes of this are:
     1. The file at the given URL simply isn't a Realm file at all.
     2. The wrong encryption key was given.
     3. The Realm file is encrypted and no encryption key was given.
     4. The Realm file isn't encrypted but an encryption key was given.
     5. The file on disk has become corrupted.
     */
    LEGACYErrorInvalidDatabase = 20,

    /**
     Denotes an error that occurs if a Realm is opened in the wrong history
     mode. Typically this means that either a local Realm is being opened as a
     synchronized Realm or vice versa.
     */
    LEGACYErrorIncompatibleHistories = 21,

    /**
     Denotes an error that occurs if objects were written to a flexible sync
     Realm without any active subscriptions for that object type. All objects
     created in flexible sync Realms must match at least one active
     subscription or the server will reject the write.
     */
    LEGACYErrorNoSubscriptionForWrite = 22,
};

#pragma mark - LEGACYSyncError

/// A user info key for use with `LEGACYSyncErrorClientResetError`.
extern NSString *const kLEGACYSyncPathOfRealmBackupCopyKey;

/// A user info key for use with certain error types.
extern NSString *const kLEGACYSyncErrorActionTokenKey;

/**
 An error related to a problem that might be reported by the synchronization manager
 error handler, or a callback on a sync-related API that performs asynchronous work.
 */
typedef LEGACY_ERROR_ENUM(NSInteger, LEGACYSyncError, LEGACYSyncErrorDomain) {
    /// An error that indicates a problem with the session (a specific Realm opened for sync).
    LEGACYSyncErrorClientSessionError      = 4,

    /// An error that indicates a problem with a specific user.
    LEGACYSyncErrorClientUserError         = 5,

    /**
     An error that indicates an internal, unrecoverable problem
     with the underlying synchronization engine.
     */
    LEGACYSyncErrorClientInternalError     = 6,

    /**
     An error that indicates the Realm needs to be reset.

     A synced Realm may need to be reset because Atlas App Services encountered an
     error and had to be restored from a backup. If the backup copy of the remote Realm
     is of an earlier version than the local copy of the Realm, the server will ask the
     client to reset the Realm.

     The reset process is as follows: the local copy of the Realm is copied into a recovery
     directory for safekeeping, and then deleted from the original location. The next time
     the Realm for that partition value is opened, the Realm will automatically be re-downloaded from
     Atlas App Services, and can be used as normal.

     Data written to the Realm after the local copy of the Realm diverged from the backup
     remote copy will be present in the local recovery copy of the Realm file. The
     re-downloaded Realm will initially contain only the data present at the time the Realm
     was backed up on the server.

     The client reset process can be initiated in one of two ways.

     The `userInfo` dictionary contains an opaque token object under the key
     `kLEGACYSyncErrorActionTokenKey`. This token can be passed into
     `+[LEGACYSyncSession immediatelyHandleError:]` in order to immediately perform the client
     reset process. This should only be done after your app closes and invalidates every
     instance of the offending Realm on all threads (note that autorelease pools may make this
     difficult to guarantee).

     If `+[LEGACYSyncSession immediatelyHandleError:]` is not called, the client reset process
     will be automatically carried out the next time the app is launched and the
     `LEGACYSyncManager` is accessed.

     The value for the `kLEGACYSyncPathOfRealmBackupCopyKey` key in the `userInfo` dictionary
     describes the path of the recovered copy of the Realm. This copy will not actually be
     created until the client reset process is initiated.

     @see `-[NSError rlmSync_errorActionToken]`, `-[NSError rlmSync_clientResetBackedUpRealmPath]`
     */
    LEGACYSyncErrorClientResetError        = 7,

    /// :nodoc:
    LEGACYSyncErrorUnderlyingAuthError     = 8,

    /**
     An error that indicates the user does not have permission to perform an operation
     upon a synced Realm. For example, a user may receive this error if they attempt to
     open a Realm they do not have at least read access to, or write to a Realm they only
     have read access to.

     This error may also occur if a user incorrectly opens a Realm they have read-only
     permissions to without using the `asyncOpen()` APIs.

     A Realm that suffers a permission denied error is, by default, flagged so that its
     local copy will be deleted the next time the application starts.

     The `userInfo` dictionary contains an opaque token object under the key
     `kLEGACYSyncErrorActionTokenKey`. This token can be passed into
     `+[LEGACYSyncSession immediatelyHandleError:]` in order to immediately delete the local
     copy. This should only be done after your app closes and invalidates every instance
     of the offending Realm on all threads (note that autorelease pools may make this
     difficult to guarantee).

     @warning It is strongly recommended that, if a Realm has encountered a permission denied
              error, its files be deleted before attempting to re-open it.

     @see `-[NSError rlmSync_errorActionToken]`
     */
    LEGACYSyncErrorPermissionDeniedError   = 9,

    /**
     An error that indicates that the server has rejected the requested flexible sync subscriptions.
     */
    LEGACYSyncErrorInvalidFlexibleSyncSubscriptions = 10,

    /**
     An error that indicates that the server has reverted a write made by this
     client. This can happen due to not having write permission, or because an
     object was created in a flexible sync Realm which does not match any
     active subscriptions.

     This error is informational and does not require any explicit handling.
     */
    LEGACYSyncErrorWriteRejected = 11,

    /**
     A connection error without a more specific error code occurred.

     Realm internally handles retrying connections with appropriate backoffs,
     so connection errors are normally logged and not reported to the error
     handler. The exception is if
     ``LEGACYSyncConfiguration.cancelAsyncOpenOnNonFatalErrors`` is set to `true`,
     in which case async opens will be canceled on connection failures and the
     error will be reported to the completion handler.

     Note that connection timeouts are reported as
     (errorDomain: NSPosixErrorDomain, error: ETIMEDOUT)
     and not as one of these error codes.
     */
    LEGACYSyncErrorConnectionFailed = 12,

    /**
     Connecting to the server failed due to a TLS issue such as an invalid certificate.
     */
    LEGACYSyncErrorTLSHandshakeFailed = 13,
};

#pragma mark - LEGACYSyncAuthError

// NEXT-MAJOR: This was a ROS thing and should have been removed in v10
/// :nodoc:
typedef LEGACY_ERROR_ENUM(NSInteger, LEGACYSyncAuthError, LEGACYSyncAuthErrorDomain) {
    LEGACYSyncAuthErrorBadResponse                     = 1,
    LEGACYSyncAuthErrorBadRemoteRealmPath              = 2,
    LEGACYSyncAuthErrorHTTPStatusCodeError             = 3,
    LEGACYSyncAuthErrorClientSessionError              = 4,
    LEGACYSyncAuthErrorInvalidParameters               = 601,
    LEGACYSyncAuthErrorMissingPath                     = 602,
    LEGACYSyncAuthErrorInvalidCredential               = 611,
    LEGACYSyncAuthErrorUserDoesNotExist                = 612,
    LEGACYSyncAuthErrorUserAlreadyExists               = 613,
    LEGACYSyncAuthErrorAccessDeniedOrInvalidPath       = 614,
    LEGACYSyncAuthErrorInvalidAccessToken              = 615,
    LEGACYSyncAuthErrorFileCannotBeShared              = 703,
} __attribute__((deprecated("Errors of this type are no longer reported")));

#pragma mark - LEGACYSyncAppError

/// An error which occurred when making a request to Atlas App Services.
typedef LEGACY_ERROR_ENUM(NSInteger, LEGACYAppError, LEGACYAppErrorDomain) {
    /// An unknown error has occurred
    LEGACYAppErrorUnknown = -1,

    /// A HTTP request completed with an error status code. The failing status
    /// code can be found in the ``LEGACYHTTPStatusCodeKey`` key of the userInfo
    /// dictionary.
    LEGACYAppErrorHttpRequestFailed = 1,

    /// A user's session is in an invalid state. Logging out and back in may rectify this.
    LEGACYAppErrorInvalidSession,
    /// A request sent to the server was malformed in some way.
    LEGACYAppErrorBadRequest,
    /// A request was made using a nonexistent user.
    LEGACYAppErrorUserNotFound,
    /// A request was made against an App using a User which does not belong to that App.
    LEGACYAppErrorUserAppDomainMismatch,
    /// The auth provider has limited the domain names which can be used for email addresses, and the given one is not allowed.
    LEGACYAppErrorDomainNotAllowed,
    /// The request body size exceeded a server-configured limit.
    LEGACYAppErrorReadSizeLimitExceeded,
    /// A request had an invalid parameter.
    LEGACYAppErrorInvalidParameter,
    /// A request was missing a required parameter.
    LEGACYAppErrorMissingParameter,
    /// Executing the requested server function failed with an error.
    LEGACYAppErrorFunctionExecutionError,
    /// The server encountered an internal error.
    LEGACYAppErrorInternalServerError,
    /// Authentication failed due to the request auth provider not existing.
    LEGACYAppErrorAuthProviderNotFound,
    /// The requested value does not exist.
    LEGACYAppErrorValueNotFound,
    /// The value being created already exists.
    LEGACYAppErrorValueAlreadyExists,
    /// A value with the same name as the value being created already exists.
    LEGACYAppErrorValueDuplicateName,
    /// The called server function does not exist.
    LEGACYAppErrorFunctionNotFound,
    /// The called server function has a syntax error.
    LEGACYAppErrorFunctionSyntaxError,
    /// The called server function is invalid in some way.
    LEGACYAppErrorFunctionInvalid,
    /// Registering an API key with the auth provider failed due to it already existing.
    LEGACYAppErrorAPIKeyAlreadyExists,
    /// The operation failed due to exceeding the server-configured time limit.
    LEGACYAppErrorExecutionTimeLimitExceeded,
    /// The body of the called function does not define a callable thing.
    LEGACYAppErrorNotCallable,
    /// Email confirmation failed for a user because the user has already confirmed their email.
    LEGACYAppErrorUserAlreadyConfirmed,
    /// The user cannot be used because it has been disabled.
    LEGACYAppErrorUserDisabled,
    /// An auth error occurred which does not have a more specific error code.
    LEGACYAppErrorAuthError,
    /// Account registration failed due to the user name already being taken.
    LEGACYAppErrorAccountNameInUse,
    /// A login request failed due to an invalid password.
    LEGACYAppErrorInvalidPassword,
    /// Operation failed due to server-side maintenance.
    LEGACYAppErrorMaintenanceInProgress,
    /// Operation failed due to an error reported by MongoDB.
    LEGACYAppErrorMongoDBError,
};

/// Extended information about a write which was rejected by the server.
///
/// The server will sometimes reject writes made by the client for reasons such
/// as permissions, additional server-side validation failing, or because the
/// object didn't match any flexible sync subscriptions. When this happens, a
/// ``LEGACYSyncErrorWriteRejected`` error is reported which contains an array of
/// `LEGACYCompensatingWriteInfo` objects in the ``LEGACYCompensatingWriteInfoKey``
/// userInfo key with information about what writes were rejected and why.
///
/// This information is intended for debugging and logging purposes only. The
/// `reason` strings are generated by the server and are not guaranteed to be
/// stable, so attempting to programmatically do anything with them will break
/// without warning.
LEGACY_SWIFT_SENDABLE LEGACY_FINAL
@interface LEGACYCompensatingWriteInfo : NSObject
/// The class name of the object being written to.
@property (nonatomic, readonly) NSString *objectType;
/// The primary key of the object being written to.
@property (nonatomic, readonly) id<LEGACYValue> primaryKey NS_REFINED_FOR_SWIFT;
/// A human-readable string describing why the write was rejected.
@property (nonatomic, readonly) NSString *reason;
@end
