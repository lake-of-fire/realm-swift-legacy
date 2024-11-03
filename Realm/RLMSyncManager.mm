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

#import "LEGACYSyncManager_Private.hpp"

#import "LEGACYApp_Private.hpp"
#import "LEGACYSyncSession_Private.hpp"
#import "LEGACYUser_Private.hpp"
#import "LEGACYSyncUtil_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/sync/config.hpp>
#import <realm/object-store/sync/sync_manager.hpp>
#import <realm/object-store/sync/sync_session.hpp>

#if !defined(REALM_COCOA_VERSION)
#import "LEGACYVersion.h"
#endif

#include <os/lock.h>

using namespace realm;

// NEXT-MAJOR: All the code associated to the logger from sync manager should be removed.
using Level = realm::util::Logger::Level;

namespace {
Level levelForSyncLogLevel(LEGACYSyncLogLevel logLevel) {
    switch (logLevel) {
        case LEGACYSyncLogLevelOff:    return Level::off;
        case LEGACYSyncLogLevelFatal:  return Level::fatal;
        case LEGACYSyncLogLevelError:  return Level::error;
        case LEGACYSyncLogLevelWarn:   return Level::warn;
        case LEGACYSyncLogLevelInfo:   return Level::info;
        case LEGACYSyncLogLevelDetail: return Level::detail;
        case LEGACYSyncLogLevelDebug:  return Level::debug;
        case LEGACYSyncLogLevelTrace:  return Level::trace;
        case LEGACYSyncLogLevelAll:    return Level::all;
    }
    REALM_UNREACHABLE();    // Unrecognized log level.
}

LEGACYSyncLogLevel logLevelForLevel(Level logLevel) {
    switch (logLevel) {
        case Level::off:    return LEGACYSyncLogLevelOff;
        case Level::fatal:  return LEGACYSyncLogLevelFatal;
        case Level::error:  return LEGACYSyncLogLevelError;
        case Level::warn:   return LEGACYSyncLogLevelWarn;
        case Level::info:   return LEGACYSyncLogLevelInfo;
        case Level::detail: return LEGACYSyncLogLevelDetail;
        case Level::debug:  return LEGACYSyncLogLevelDebug;
        case Level::trace:  return LEGACYSyncLogLevelTrace;
        case Level::all:    return LEGACYSyncLogLevelAll;
    }
    REALM_UNREACHABLE();    // Unrecognized log level.
}

#pragma mark - Loggers

struct CocoaSyncLogger : public realm::util::Logger {
    void do_log(Level, const std::string& message) override {
        NSLog(@"Sync: %@", LEGACYStringDataToNSString(message));
    }
};

static std::unique_ptr<realm::util::Logger> defaultSyncLogger(realm::util::Logger::Level level) {
    auto logger = std::make_unique<CocoaSyncLogger>();
    logger->set_level_threshold(level);
    return std::move(logger);
}

struct CallbackLogger : public realm::util::Logger {
    LEGACYSyncLogFunction logFn;
    void do_log(Level level, const std::string& message) override {
        @autoreleasepool {
            logFn(logLevelForLevel(level), LEGACYStringDataToNSString(message));
        }
    }
};

} // anonymous namespace

std::shared_ptr<realm::util::Logger> LEGACYWrapLogFunction(LEGACYSyncLogFunction fn) {
    auto logger = std::make_shared<CallbackLogger>();
    logger->logFn = fn;
    logger->set_level_threshold(Level::all);
    return logger;
}

#pragma mark - LEGACYSyncManager

@implementation LEGACYSyncManager {
    LEGACYUnfairMutex _mutex;
    std::shared_ptr<SyncManager> _syncManager;
    NSDictionary<NSString *,NSString *> *_customRequestHeaders;
    LEGACYSyncLogFunction _logger;
}

- (instancetype)initWithSyncManager:(std::shared_ptr<realm::SyncManager>)syncManager {
    if (self = [super init]) {
        _syncManager = syncManager;
        return self;
    }
    return nil;
}

- (std::weak_ptr<realm::app::App>)app {
    return _syncManager->app();
}

- (NSDictionary<NSString *,NSString *> *)customRequestHeaders {
    std::lock_guard lock(_mutex);
    return _customRequestHeaders;
}

- (void)setCustomRequestHeaders:(NSDictionary<NSString *,NSString *> *)customRequestHeaders {
    {
        std::lock_guard lock(_mutex);
        _customRequestHeaders = customRequestHeaders.copy;
    }

    for (auto&& user : _syncManager->all_users()) {
        for (auto&& session : user->all_sessions()) {
            auto config = session->config();
            config.custom_http_headers.clear();
            for (NSString *key in customRequestHeaders) {
                config.custom_http_headers.emplace(key.UTF8String, customRequestHeaders[key].UTF8String);
            }
            session->update_configuration(std::move(config));
        }
    }
}

- (LEGACYSyncLogFunction)logger {
    std::lock_guard lock(_mutex);
    return _logger;
}

- (void)setLogger:(LEGACYSyncLogFunction)logFn {
    {
        std::lock_guard lock(_mutex);
        _logger = logFn;
    }
    if (logFn) {
        _syncManager->set_logger_factory([logFn](realm::util::Logger::Level level) {
            auto logger = std::make_unique<CallbackLogger>();
            logger->logFn = logFn;
            logger->set_level_threshold(level);
            return logger;
        });
    }
    else {
        _syncManager->set_logger_factory(defaultSyncLogger);
    }
}

#pragma mark - Passthrough properties

- (NSString *)userAgent {
    return @(_syncManager->config().user_agent_application_info.c_str());
}

- (void)setUserAgent:(NSString *)userAgent {
    _syncManager->set_user_agent(LEGACYStringDataWithNSString(userAgent));
}

- (LEGACYSyncTimeoutOptions *)timeoutOptions {
    return [[LEGACYSyncTimeoutOptions alloc] initWithOptions:_syncManager->config().timeouts];
}

- (void)setTimeoutOptions:(LEGACYSyncTimeoutOptions *)timeoutOptions {
    _syncManager->set_timeouts(timeoutOptions->_options);
}

- (LEGACYSyncLogLevel)logLevel {
    return logLevelForLevel(_syncManager->log_level());
}

- (void)setLogLevel:(LEGACYSyncLogLevel)logLevel {
    _syncManager->set_log_level(levelForSyncLogLevel(logLevel));
}

#pragma mark - Private API

- (void)resetForTesting {
    _errorHandler = nil;
    _logger = nil;
    _authorizationHeaderName = nil;
    _customRequestHeaders = nil;
    _syncManager->reset_for_testing();
}

- (std::shared_ptr<realm::SyncManager>)syncManager {
    return _syncManager;
}

- (void)waitForSessionTermination {
    _syncManager->wait_for_sessions_to_terminate();
}

- (void)populateConfig:(realm::SyncConfig&)config {
    @synchronized (self) {
        if (_authorizationHeaderName) {
            config.authorization_header_name.emplace(_authorizationHeaderName.UTF8String);
        }
        [_customRequestHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *header, BOOL *) {
            config.custom_http_headers.emplace(key.UTF8String, header.UTF8String);
        }];
    }
}
@end

#pragma mark - LEGACYSyncTimeoutOptions

@implementation LEGACYSyncTimeoutOptions
- (instancetype)initWithOptions:(realm::SyncClientTimeouts)options {
    if (self = [super init]) {
        _options = options;
    }
    return self;
}

- (NSUInteger)connectTimeout {
    return static_cast<NSUInteger>(_options.connect_timeout);
}
- (void)setConnectTimeout:(NSUInteger)connectTimeout {
    _options.connect_timeout = connectTimeout;
}

- (NSUInteger)connectLingerTime {
    return static_cast<NSUInteger>(_options.connection_linger_time);
}
- (void)setConnectionLingerTime:(NSUInteger)connectionLingerTime {
    _options.connection_linger_time = connectionLingerTime;
}

- (NSUInteger)pingKeepalivePeriod {
    return static_cast<NSUInteger>(_options.ping_keepalive_period);
}
- (void)setPingKeepalivePeriod:(NSUInteger)pingKeepalivePeriod {
    _options.ping_keepalive_period = pingKeepalivePeriod;
}

- (NSUInteger)pongKeepaliveTimeout {
    return static_cast<NSUInteger>(_options.pong_keepalive_timeout);
}
- (void)setPongKeepaliveTimeout:(NSUInteger)pongKeepaliveTimeout {
    _options.pong_keepalive_timeout = pongKeepaliveTimeout;
}

- (NSUInteger)fastReconnectLimit {
    return static_cast<NSUInteger>(_options.fast_reconnect_limit);
}
- (void)setFastReconnectLimit:(NSUInteger)fastReconnectLimit {
    _options.fast_reconnect_limit = fastReconnectLimit;
}

@end
