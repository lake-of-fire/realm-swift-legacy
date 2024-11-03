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

#import "LEGACYError_Private.hpp"

#import "LEGACYUtil.hpp"
#import "LEGACYSyncSession_Private.hpp"

#import <realm/object-store/sync/app.hpp>
#import <realm/util/basic_system_errors.hpp>
#import <realm/sync/client.hpp>

// NEXT-MAJOR: we should merge these all into a single error domain/error enum
NSString *const LEGACYErrorDomain                   = @"io.realm";
NSString *const LEGACYUnknownSystemErrorDomain      = @"io.realm.unknown";
NSString *const LEGACYSyncErrorDomain               = @"io.realm.sync";
NSString *const LEGACYSyncAuthErrorDomain           = @"io.realm.sync.auth";
NSString *const LEGACYAppErrorDomain                = @"io.realm.app";

NSString *const kLEGACYSyncPathOfRealmBackupCopyKey = @"recovered_realm_location_path";
NSString *const kLEGACYSyncErrorActionTokenKey      = @"error_action_token";
NSString *const LEGACYErrorCodeKey                  = @"Error Code";
NSString *const LEGACYErrorCodeNameKey              = @"Error Name";
NSString *const LEGACYServerLogURLKey               = @"Server Log URL";
NSString *const LEGACYCompensatingWriteInfoKey      = @"Compensating Write Info";
NSString *const LEGACYHTTPStatusCodeKey             = @"HTTP Status Code";
static NSString *const LEGACYDeprecatedErrorCodeKey = @"Error Code";

namespace {
NSInteger translateFileError(realm::ErrorCodes::Error code) {
    using ec = realm::ErrorCodes::Error;
    switch (code) {
        // Local errors
        case ec::AddressSpaceExhausted:                return LEGACYErrorAddressSpaceExhausted;
        case ec::DeleteOnOpenRealm:                    return LEGACYErrorAlreadyOpen;
        case ec::FileAlreadyExists:                    return LEGACYErrorFileExists;
        case ec::FileFormatUpgradeRequired:            return LEGACYErrorFileFormatUpgradeRequired;
        case ec::FileNotFound:                         return LEGACYErrorFileNotFound;
        case ec::FileOperationFailed:                  return LEGACYErrorFileOperationFailed;
        case ec::IncompatibleHistories:                return LEGACYErrorIncompatibleHistories;
        case ec::IncompatibleLockFile:                 return LEGACYErrorIncompatibleLockFile;
        case ec::IncompatibleSession:                  return LEGACYErrorIncompatibleSession;
        case ec::InvalidDatabase:                      return LEGACYErrorInvalidDatabase;
        case ec::MultipleSyncAgents:                   return LEGACYErrorMultipleSyncAgents;
        case ec::NoSubscriptionForWrite:               return LEGACYErrorNoSubscriptionForWrite;
        case ec::OutOfDiskSpace:                       return LEGACYErrorOutOfDiskSpace;
        case ec::PermissionDenied:                     return LEGACYErrorFilePermissionDenied;
        case ec::SchemaMismatch:                       return LEGACYErrorSchemaMismatch;
        case ec::SubscriptionFailed:                   return LEGACYErrorSubscriptionFailed;
        case ec::UnsupportedFileFormatVersion:         return LEGACYErrorUnsupportedFileFormatVersion;

        // Sync errors
        case ec::AuthError:                            return LEGACYSyncErrorClientUserError;
        case ec::SyncPermissionDenied:                 return LEGACYSyncErrorPermissionDeniedError;
        case ec::SyncCompensatingWrite:                return LEGACYSyncErrorWriteRejected;
        case ec::SyncConnectFailed:                    return LEGACYSyncErrorConnectionFailed;
        case ec::TlsHandshakeFailed:                   return LEGACYSyncErrorTLSHandshakeFailed;
        case ec::SyncConnectTimeout:                   return ETIMEDOUT;

        // App errors
        case ec::APIKeyAlreadyExists:                  return LEGACYAppErrorAPIKeyAlreadyExists;
        case ec::AccountNameInUse:                     return LEGACYAppErrorAccountNameInUse;
        case ec::AppUnknownError:                      return LEGACYAppErrorUnknown;
        case ec::AuthProviderNotFound:                 return LEGACYAppErrorAuthProviderNotFound;
        case ec::DomainNotAllowed:                     return LEGACYAppErrorDomainNotAllowed;
        case ec::ExecutionTimeLimitExceeded:           return LEGACYAppErrorExecutionTimeLimitExceeded;
        case ec::FunctionExecutionError:               return LEGACYAppErrorFunctionExecutionError;
        case ec::FunctionInvalid:                      return LEGACYAppErrorFunctionInvalid;
        case ec::FunctionNotFound:                     return LEGACYAppErrorFunctionNotFound;
        case ec::FunctionSyntaxError:                  return LEGACYAppErrorFunctionSyntaxError;
        case ec::InvalidPassword:                      return LEGACYAppErrorInvalidPassword;
        case ec::InvalidSession:                       return LEGACYAppErrorInvalidSession;
        case ec::MaintenanceInProgress:                return LEGACYAppErrorMaintenanceInProgress;
        case ec::MissingParameter:                     return LEGACYAppErrorMissingParameter;
        case ec::MongoDBError:                         return LEGACYAppErrorMongoDBError;
        case ec::NotCallable:                          return LEGACYAppErrorNotCallable;
        case ec::ReadSizeLimitExceeded:                return LEGACYAppErrorReadSizeLimitExceeded;
        case ec::UserAlreadyConfirmed:                 return LEGACYAppErrorUserAlreadyConfirmed;
        case ec::UserAppDomainMismatch:                return LEGACYAppErrorUserAppDomainMismatch;
        case ec::UserDisabled:                         return LEGACYAppErrorUserDisabled;
        case ec::UserNotFound:                         return LEGACYAppErrorUserNotFound;
        case ec::ValueAlreadyExists:                   return LEGACYAppErrorValueAlreadyExists;
        case ec::ValueDuplicateName:                   return LEGACYAppErrorValueDuplicateName;
        case ec::ValueNotFound:                        return LEGACYAppErrorValueNotFound;

        case ec::AWSError:
        case ec::GCMError:
        case ec::HTTPError:
        case ec::InternalServerError:
        case ec::TwilioError:
            return LEGACYAppErrorInternalServerError;

        case ec::ArgumentsNotAllowed:
        case ec::BadRequest:
        case ec::InvalidParameter:
            return LEGACYAppErrorBadRequest;

        default: {
            auto category = realm::ErrorCodes::error_categories(code);
            if (category.test(realm::ErrorCategory::file_access)) {
                return LEGACYErrorFileAccess;
            }
            if (category.test(realm::ErrorCategory::app_error)) {
                return LEGACYAppErrorUnknown;
            }
            if (category.test(realm::ErrorCategory::sync_error)) {
                return LEGACYSyncErrorClientInternalError;
            }
            return LEGACYErrorFail;
        }
    }
}

NSString *errorDomain(realm::ErrorCodes::Error error) {
    // Special-case errors where our error domain doesn't match core's category
    // NEXT-MAJOR: we should unify everything into LEGACYErrorDomain
    using ec = realm::ErrorCodes::Error;
    switch (error) {
        case ec::SubscriptionFailed:
            return LEGACYErrorDomain;
        case ec::SyncConnectTimeout:
            return NSPOSIXErrorDomain;
        default:
            break;
    }

    auto category = realm::ErrorCodes::error_categories(error);
    if (category.test(realm::ErrorCategory::sync_error)) {
        return LEGACYSyncErrorDomain;
    }
    if (category.test(realm::ErrorCategory::app_error)) {
        return LEGACYAppErrorDomain;
    }
    return LEGACYErrorDomain;
}

NSString *errorString(realm::ErrorCodes::Error error) {
    return LEGACYStringViewToNSString(realm::ErrorCodes::error_string(error));
}

NSError *translateSystemError(std::error_code ec, const char *msg) {
    int code = ec.value();
    BOOL isGenericCategoryError = ec.category() == std::generic_category()
                               || ec.category() == realm::util::error::basic_system_error_category();
    NSString *errorDomain = isGenericCategoryError ? NSPOSIXErrorDomain : LEGACYUnknownSystemErrorDomain;

    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    userInfo[NSLocalizedDescriptionKey] = @(msg);
    // FIXME: remove these in v11
    userInfo[@"Error Code"] = @(code);
    userInfo[@"Category"] = @(ec.category().name());

    return [NSError errorWithDomain:errorDomain code:code userInfo:userInfo.copy];
}
} // anonymous namespace

NSError *makeError(realm::Status const& status) {
    if (status.is_ok()) {
        return nil;
    }
    auto code = translateFileError(status.code());
    return [NSError errorWithDomain:errorDomain(status.code())
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: @(status.reason().c_str()),
                                      LEGACYDeprecatedErrorCodeKey: @(code),
                                      LEGACYErrorCodeNameKey: errorString(status.code())}];
}

NSError *makeError(realm::Exception const& exception) {
    NSInteger code = translateFileError(exception.code());
    return [NSError errorWithDomain:errorDomain(exception.code())
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: @(exception.what()),
                                      LEGACYDeprecatedErrorCodeKey: @(code),
                                      LEGACYErrorCodeNameKey: errorString(exception.code())}];

}

NSError *makeError(realm::FileAccessError const& exception) {
    NSInteger code = translateFileError(exception.code());
    return [NSError errorWithDomain:errorDomain(exception.code())
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: @(exception.what()),
                                      NSFilePathErrorKey: @(exception.get_path().data()),
                                      LEGACYDeprecatedErrorCodeKey: @(code),
                                      LEGACYErrorCodeNameKey: errorString(exception.code())}];
}

NSError *makeError(std::exception const& exception) {
    return [NSError errorWithDomain:LEGACYErrorDomain
                               code:LEGACYErrorFail
                           userInfo:@{NSLocalizedDescriptionKey: @(exception.what())}];
}

NSError *makeError(std::system_error const& exception) {
    return translateSystemError(exception.code(), exception.what());
}

__attribute__((objc_direct_members))
@implementation LEGACYCompensatingWriteInfo {
    realm::sync::CompensatingWriteErrorInfo _info;
}

- (instancetype)initWithInfo:(realm::sync::CompensatingWriteErrorInfo&&)info {
    if ((self = [super init])) {
        _info = std::move(info);
    }
    return self;
}

- (NSString *)objectType {
    return @(_info.object_name.c_str());
}

- (NSString *)reason {
    return @(_info.reason.c_str());
}

- (id<LEGACYValue>)primaryKey {
    return LEGACYMixedToObjc(_info.primary_key);
}
@end

NSError *makeError(realm::SyncError&& error) {
    auto& status = error.status;
    if (status.is_ok()) {
        return nil;
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    userInfo[NSLocalizedDescriptionKey] = LEGACYStringViewToNSString(error.simple_message);
    if (!error.logURL.empty()) {
        userInfo[LEGACYServerLogURLKey] = LEGACYStringViewToNSString(error.logURL);
    }
    if (!error.compensating_writes_info.empty()) {
        NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:error.compensating_writes_info.size()];
        for (auto& info : error.compensating_writes_info) {
            [array addObject:[[LEGACYCompensatingWriteInfo alloc] initWithInfo:std::move(info)]];
        }
        userInfo[LEGACYCompensatingWriteInfoKey] = [array copy];
    }
    for (auto& pair : error.user_info) {
        if (pair.first == realm::SyncError::c_original_file_path_key) {
            userInfo[kLEGACYSyncErrorActionTokenKey] =
                [[LEGACYSyncErrorActionToken alloc] initWithOriginalPath:pair.second];
        }
        else if (pair.first == realm::SyncError::c_recovery_file_path_key) {
            userInfo[kLEGACYSyncPathOfRealmBackupCopyKey] = @(pair.second.c_str());
        }
    }

    int errorCode = LEGACYSyncErrorClientInternalError;
    NSString *errorDomain = LEGACYSyncErrorDomain;
    using enum realm::ErrorCodes::Error;
    auto code = error.status.code();
    bool isSyncError = realm::ErrorCodes::error_categories(code).test(realm::ErrorCategory::sync_error);
    switch (code) {
        case SyncPermissionDenied:
            errorCode = LEGACYSyncErrorPermissionDeniedError;
            break;
        case AuthError:
            errorCode = LEGACYSyncErrorClientUserError;
            break;
        case SyncCompensatingWrite:
            errorCode = LEGACYSyncErrorWriteRejected;
            break;
        case SyncConnectFailed:
            errorCode = LEGACYSyncErrorConnectionFailed;
            break;
        case SyncConnectTimeout:
            errorCode = ETIMEDOUT;
            errorDomain = NSPOSIXErrorDomain;
            break;

        default:
            if (error.is_client_reset_requested())
                errorCode = LEGACYSyncErrorClientResetError;
            else if (isSyncError)
                errorCode = LEGACYSyncErrorClientSessionError;
            else if (!error.is_fatal)
                return nil;
            break;
    }

    return [NSError errorWithDomain:errorDomain code:errorCode userInfo:userInfo.copy];
}

NSError *makeError(realm::app::AppError const& appError) {
    auto& status = appError.to_status();
    if (status.is_ok()) {
        return nil;
    }

    // Core uses the same error code for both sync and app auth errors, but we
    // have separate ones
    auto code = translateFileError(status.code());
    auto domain = errorDomain(status.code());
    if (domain == LEGACYSyncErrorDomain && code == LEGACYSyncErrorClientUserError) {
        domain = LEGACYAppErrorDomain;
        code = LEGACYAppErrorAuthError;
    }
    return [NSError errorWithDomain:domain code:code
                           userInfo:@{NSLocalizedDescriptionKey: @(status.reason().c_str()),
                                      LEGACYDeprecatedErrorCodeKey: @(code),
                                      LEGACYErrorCodeNameKey: errorString(status.code()),
                                      LEGACYServerLogURLKey: @(appError.link_to_server_logs.c_str())}];
}
