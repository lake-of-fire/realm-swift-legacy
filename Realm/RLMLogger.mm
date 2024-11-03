////////////////////////////////////////////////////////////////////////////
//
// Copyright 2023 Realm Inc.
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

#import "LEGACYLogger_Private.h"

#import "LEGACYUtil.hpp"

#import <realm/util/logger.hpp>

typedef void (^LEGACYLoggerFunction)(LEGACYLogLevel level, NSString *message);

using namespace realm;
using Logger = realm::util::Logger;
using Level = Logger::Level;

namespace {
static Level levelForLogLevel(LEGACYLogLevel logLevel) {
    switch (logLevel) {
        case LEGACYLogLevelOff:    return Level::off;
        case LEGACYLogLevelFatal:  return Level::fatal;
        case LEGACYLogLevelError:  return Level::error;
        case LEGACYLogLevelWarn:   return Level::warn;
        case LEGACYLogLevelInfo:   return Level::info;
        case LEGACYLogLevelDetail: return Level::detail;
        case LEGACYLogLevelDebug:  return Level::debug;
        case LEGACYLogLevelTrace:  return Level::trace;
        case LEGACYLogLevelAll:    return Level::all;
    }
    REALM_UNREACHABLE();    // Unrecognized log level.
}

static LEGACYLogLevel logLevelForLevel(Level logLevel) {
    switch (logLevel) {
        case Level::off:    return LEGACYLogLevelOff;
        case Level::fatal:  return LEGACYLogLevelFatal;
        case Level::error:  return LEGACYLogLevelError;
        case Level::warn:   return LEGACYLogLevelWarn;
        case Level::info:   return LEGACYLogLevelInfo;
        case Level::detail: return LEGACYLogLevelDetail;
        case Level::debug:  return LEGACYLogLevelDebug;
        case Level::trace:  return LEGACYLogLevelTrace;
        case Level::all:    return LEGACYLogLevelAll;
    }
    REALM_UNREACHABLE();    // Unrecognized log level.
}

static NSString* levelPrefix(Level logLevel) {
    switch (logLevel) {
        case Level::off:
        case Level::all:    return @"";
        case Level::trace:  return @"Trace";
        case Level::debug:  return @"Debug";
        case Level::detail: return @"Detail";
        case Level::info:   return @"Info";
        case Level::error:  return @"Error";
        case Level::warn:   return @"Warning";
        case Level::fatal:  return @"Fatal";
    }
    REALM_UNREACHABLE();    // Unrecognized log level.
}

struct CocoaLogger : public Logger {
    void do_log(Level level, const std::string& message) override {
        NSLog(@"%@: %@", levelPrefix(level), LEGACYStringDataToNSString(message));
    }
};

class CustomLogger : public Logger {
public:
    LEGACYLoggerFunction function;
    void do_log(Level level, const std::string& message) override {
        @autoreleasepool {
            if (function) {
                function(logLevelForLevel(level), LEGACYStringDataToNSString(message));
            }
        }
    }
};
} // anonymous namespace

@implementation LEGACYLogger {
    std::shared_ptr<Logger> _logger;
}

typedef void(^LoggerBlock)(LEGACYLogLevel level, NSString *message);

- (LEGACYLogLevel)level {
    return logLevelForLevel(_logger->get_level_threshold());
}

- (void)setLevel:(LEGACYLogLevel)level {
    _logger->set_level_threshold(levelForLogLevel(level));
}

+ (void)initialize {
    auto defaultLogger = std::make_shared<CocoaLogger>();
    defaultLogger->set_level_threshold(Level::info);
    Logger::set_default_logger(defaultLogger);
}

- (instancetype)initWithLogger:(std::shared_ptr<Logger>)logger {
    if (self = [self init]) {
        self->_logger = logger;
    }
    return self;
}

- (instancetype)initWithLevel:(LEGACYLogLevel)level logFunction:(LEGACYLogFunction)logFunction {
    if (self = [super init]) {
        auto logger = std::make_shared<CustomLogger>();
        logger->set_level_threshold(levelForLogLevel(level));
        logger->function = logFunction;
        self->_logger = logger;
    }
    return self;
}

- (void)logWithLevel:(LEGACYLogLevel)logLevel message:(NSString *)message, ... {
    auto level = levelForLogLevel(logLevel);
    if (_logger->would_log(level)) {
        va_list args;
        va_start(args, message);
        _logger->log(level, "%1", [[NSString alloc] initWithFormat:message arguments:args].UTF8String);
        va_end(args);
    }
}

- (void)logLevel:(LEGACYLogLevel)logLevel message:(NSString *)message {
    auto level = levelForLogLevel(logLevel);
    if (_logger->would_log(level)) {
        _logger->log(level, "%1", message.UTF8String);
    }
}

#pragma mark Global Logger Setter

+ (instancetype)defaultLogger {
    return [[LEGACYLogger alloc] initWithLogger:Logger::get_default_logger()];
}

+ (void)setDefaultLogger:(LEGACYLogger *)logger {
    Logger::set_default_logger(logger->_logger);
}
@end
