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

#import <Realm/LEGACYConstants.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability)

/// An enum representing different levels of sync-related logging that can be configured.
typedef LEGACY_CLOSED_ENUM(NSUInteger, LEGACYLogLevel) {
    /// Nothing will ever be logged.
    LEGACYLogLevelOff,
    /// Only fatal errors will be logged.
    LEGACYLogLevelFatal,
    /// Only errors will be logged.
    LEGACYLogLevelError,
    /// Warnings and errors will be logged.
    LEGACYLogLevelWarn,
    /// Information about sync events will be logged. Fewer events will be logged in order to avoid overhead.
    LEGACYLogLevelInfo,
    /// Information about sync events will be logged. More events will be logged than with `LEGACYLogLevelInfo`.
    LEGACYLogLevelDetail,
    /// Log information that can aid in debugging.
    ///
    /// - warning: Will incur a measurable performance impact.
    LEGACYLogLevelDebug,
    /// Log information that can aid in debugging. More events will be logged than with `LEGACYLogLevelDebug`.
    ///
    /// - warning: Will incur a measurable performance impact.
    LEGACYLogLevelTrace,
    /// Log information that can aid in debugging. More events will be logged than with `LEGACYLogLevelTrace`.
    ///
    /// - warning: Will incur a measurable performance impact.
    LEGACYLogLevelAll
} NS_SWIFT_NAME(LogLevel);

/// A log callback function which can be set on LEGACYLogger.
///
/// The log function may be called from multiple threads simultaneously, and is
/// responsible for performing its own synchronization if any is required.
LEGACY_SWIFT_SENDABLE // invoked on a background thread
typedef void (^LEGACYLogFunction)(LEGACYLogLevel level, NSString *message);

/**
 `LEGACYLogger` is used for creating your own custom logging logic.

 You can define your own logger creating an instance of `LEGACYLogger` and define the log function which will be
 invoked whenever there is a log message.
 Set this custom logger as you default logger using `setDefaultLogger`.

     LEGACYLogger.defaultLogger = [[LEGACYLogger alloc] initWithLevel:LEGACYLogLevelDebug
                                                logFunction:^(LEGACYLogLevel level, NSString * message) {
         NSLog(@"Realm Log - %lu, %@", (unsigned long)level, message);
     }];

 @note By default default log threshold level is `LEGACYLogLevelInfo`, and logging strings are output to Apple System Logger.
*/
@interface LEGACYLogger : NSObject

/**
  Gets the logging threshold level used by the logger.
 */
@property (nonatomic) LEGACYLogLevel level;

/// :nodoc:
- (instancetype)init NS_UNAVAILABLE;

/**
 Creates a logger with the associated log level and the logic function to define your own logging logic.

 @param level The log level to be set for the logger.
 @param logFunction The log function which will be invoked whenever there is a log message.
*/
- (instancetype)initWithLevel:(LEGACYLogLevel)level logFunction:(LEGACYLogFunction)logFunction;

#pragma mark LEGACYLogger Default Logger API

/**
 The current default logger. When setting a logger as default, this logger will be used whenever information must be logged.
 */
@property (class) LEGACYLogger *defaultLogger NS_SWIFT_NAME(shared);

@end

LEGACY_HEADER_AUDIT_END(nullability)
