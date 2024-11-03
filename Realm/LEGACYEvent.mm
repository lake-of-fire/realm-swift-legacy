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

#import <Realm/LEGACYEvent.h>

#import "LEGACYError_Private.hpp"
#import "LEGACYObjectSchema_Private.hpp"
#import "LEGACYObjectStore.h"
#import "LEGACYObject_Private.hpp"
#import "LEGACYRealmConfiguration_Private.hpp"
#import "LEGACYRealmUtil.hpp"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYSyncConfiguration_Private.hpp"
#import "LEGACYSyncManager_Private.hpp"
#import "LEGACYUser_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/audit.hpp>
#import <realm/object-store/audit_serializer.hpp>
#import <external/json/json.hpp>

using namespace realm;

@interface LEGACYObjectBase ()
- (NSString *)customEventRepresentation;
@end

namespace {
util::UniqueFunction<void (std::exception_ptr)> wrapCompletion(void (^completion)(NSError *)) {
    if (!completion) {
        return nullptr;
    }
    return [=](std::exception_ptr err) {
        @autoreleasepool {
            if (!err) {
                return completion(nil);
            }
            try {
                std::rethrow_exception(err);
            }
            catch (NSException *e) {
                auto info = @{@"ExceptionName": e.name ?: NSNull.null,
                              @"ExceptionReason": e.reason ?: NSNull.null,
                              @"ExceptionCallStackReturnAddresses": e.callStackReturnAddresses,
                              @"ExceptionCallStackSymbols": e.callStackSymbols,
                              @"ExceptionUserInfo": e.userInfo ?: NSNull.null};
                completion([NSError errorWithDomain:LEGACYErrorDomain code:LEGACYErrorFail userInfo:info]);
            }
            catch (...) {
                NSError *error;
                LEGACYRealmTranslateException(&error);
                completion(error);
            }
        }
    };
}

realm::AuditInterface *auditContext(LEGACYEventContext *context) {
    return reinterpret_cast<realm::AuditInterface *>(context);
}

std::vector<std::pair<std::string, std::string>> convertMetadata(NSDictionary *metadata) {
    std::vector<std::pair<std::string, std::string>> ret;
    ret.reserve(metadata.count);
    [metadata enumerateKeysAndObjectsUsingBlock:[&](NSString *key, NSString *value, BOOL *) {
        ret.emplace_back(key.UTF8String, value.UTF8String);
    }];
    return ret;
}

std::optional<std::string> nsStringToOptionalString(NSString *str) {
    if (!str) {
        return util::none;
    }

    std::string ret;
    LEGACYNSStringToStdString(ret, str);
    return ret;
}
} // anonymous namespace

uint64_t LEGACYEventBeginScope(LEGACYEventContext *context, NSString *activity) {
    return auditContext(context)->begin_scope(activity.UTF8String);
}

void LEGACYEventCommitScope(LEGACYEventContext *context, uint64_t scope_id, LEGACYEventCompletion completion) {
    auditContext(context)->end_scope(scope_id, wrapCompletion(completion));
}

void LEGACYEventCancelScope(LEGACYEventContext *context, uint64_t scope_id) {
    auditContext(context)->cancel_scope(scope_id);
}

bool LEGACYEventIsActive(LEGACYEventContext *context, uint64_t scope_id) {
    return auditContext(context)->is_scope_valid(scope_id);
}

void LEGACYEventRecordEvent(LEGACYEventContext *context, NSString *activity, NSString *event,
                         NSString *data, LEGACYEventCompletion completion) {
    auditContext(context)->record_event(activity.UTF8String, nsStringToOptionalString(event),
                                         nsStringToOptionalString(data), wrapCompletion(completion));
}

void LEGACYEventUpdateMetadata(LEGACYEventContext *context, NSDictionary<NSString *, NSString *> *newMetadata) {
    auditContext(context)->update_metadata(convertMetadata(newMetadata));
}

LEGACYEventContext *LEGACYEventGetContext(LEGACYRealm *realm) {
    return reinterpret_cast<LEGACYEventContext *>(realm->_realm->audit_context());
}

class LEGACYEventSerializer : public realm::AuditObjectSerializer {
public:
    LEGACYEventSerializer(LEGACYRealmConfiguration *c) : _config(c.copy) {
        auto& config = _config.configRef;
        config.cache = false;
        config.audit_config = nullptr;
        config.automatic_change_notifications = false;
    }

    ~LEGACYEventSerializer() {
        scope_complete();
    }

    void scope_complete() final {
        for (auto& [_, acc] : _accessorMap) {
            if (acc) {
                acc->_realm = nil;
                acc->_objectSchema = nil;
            }
        }
        if (_realm) {
            _realm->_realm->close();
            _realm = nil;
        }
    }

    void to_json(nlohmann::json& out, const Obj& obj) final {
        @autoreleasepool {
            auto tableKey = obj.get_table()->get_key();
            LEGACYObjectBase *acc = getAccessor(tableKey);
            if (!acc) {
                return AuditObjectSerializer::to_json(out, obj);
            }

            if (!acc->_realm) {
                acc->_realm = realm();
                acc->_info = acc->_realm->_info[tableKey];
                acc->_objectSchema = acc->_info->rlmObjectSchema;
            }

            acc->_row = obj;
            LEGACYInitializeSwiftAccessor(acc, false);
            NSString *customRepresentation = [acc customEventRepresentation];
            out = nlohmann::json::parse(customRepresentation.UTF8String);
        }
    }

private:
    LEGACYRealmConfiguration *_config;
    LEGACYRealm *_realm;
    std::unordered_map<uint32_t, LEGACYObjectBase *> _accessorMap;

    LEGACYRealm *realm() {
        if (!_realm) {
            _realm = [LEGACYRealm realmWithConfiguration:_config error:nil];
        }
        return _realm;
    }

    LEGACYObjectBase *getAccessor(TableKey tableKey) {
        auto it = _accessorMap.find(tableKey.value);
        if (it != _accessorMap.end()) {
            return it->second;
        }

        LEGACYClassInfo *info = realm()->_info[tableKey];
        if (!info || !info->rlmObjectSchema.hasCustomEventSerialization) {
            _accessorMap.insert({tableKey.value, nil});
            return nil;
        }

        LEGACYObjectBase *acc = [[info->rlmObjectSchema.accessorClass alloc] init];
        acc->_realm = realm();
        acc->_objectSchema = info->rlmObjectSchema;
        acc->_info = info;
        _accessorMap.insert({tableKey.value, acc});
        return acc;
    }
};

@implementation LEGACYEventConfiguration
- (std::shared_ptr<AuditConfig>)auditConfigWithRealmConfiguration:(LEGACYRealmConfiguration *)realmConfig {
    auto config = std::make_shared<realm::AuditConfig>();
    config->audit_user = self.syncUser._syncUser;
    config->partition_value_prefix = self.partitionPrefix.UTF8String;
    config->metadata = convertMetadata(self.metadata);
    config->serializer = std::make_shared<LEGACYEventSerializer>(realmConfig);
    if (_logger) {
        config->logger = LEGACYWrapLogFunction(_logger);
    }
    if (_errorHandler) {
        config->sync_error_handler = [eh = _errorHandler](realm::SyncError e) {
            if (auto error = makeError(std::move(e))) {
                eh(error);
            }
        };
    }
    return config;
}
@end
