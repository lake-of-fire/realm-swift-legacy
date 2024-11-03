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

#import <Realm/LEGACYLogger.h>
#import <Realm/LEGACYConstants.h>

LEGACY_HEADER_AUDIT_BEGIN(nullability)

@interface LEGACYLogger()

/**
 Log a message to the supplied level.

 @param logLevel The log level for the message.
 @param message The message to log.
 */
- (void)logWithLevel:(LEGACYLogLevel)logLevel message:(NSString *)message, ... NS_SWIFT_UNAVAILABLE("");
- (void)logLevel:(LEGACYLogLevel)logLevel message:(NSString *)message;
@end

LEGACY_HEADER_AUDIT_END(nullability)
