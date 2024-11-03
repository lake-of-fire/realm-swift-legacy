////////////////////////////////////////////////////////////////////////////
//
// Copyright 2020 Realm Inc.
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

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

@protocol LEGACYBSON;

/// Options to use when executing a `find` command on a `LEGACYMongoCollection`.
@interface LEGACYFindOptions : NSObject

/// The maximum number of documents to return. Specifying 0 will return all documents.
@property (nonatomic) NSInteger limit;

/// Limits the fields to return for all matching documents.
@property (nonatomic, nullable) id<LEGACYBSON> projection NS_REFINED_FOR_SWIFT;

/// The order in which to return matching documents.
@property (nonatomic, nullable) id<LEGACYBSON> sort NS_REFINED_FOR_SWIFT
__attribute__((deprecated("Use `sorting` instead, which correctly sort more than one sort attribute", "sorting")));

/// The order in which to return matching documents.
@property (nonatomic) NSArray<id<LEGACYBSON>> *sorting NS_REFINED_FOR_SWIFT;

/// Options to use when executing a `find` command on a `LEGACYMongoCollection`.
/// @param limit The maximum number of documents to return. Specifying 0 will return all documents.
/// @param projection Limits the fields to return for all matching documents.
/// @param sort The order in which to return matching documents.
- (instancetype)initWithLimit:(NSInteger)limit
                   projection:(id<LEGACYBSON> _Nullable)projection
                         sort:(id<LEGACYBSON> _Nullable)sort
__attribute__((deprecated("Please use `initWithLimit:projection:sorting:`")))
    NS_SWIFT_UNAVAILABLE("Please see FindOption");


/// Options to use when executing a `find` command on a `LEGACYMongoCollection`.
/// @param projection Limits the fields to return for all matching documents.
/// @param sort The order in which to return matching documents.
- (instancetype)initWithProjection:(id<LEGACYBSON> _Nullable)projection
                              sort:(id<LEGACYBSON> _Nullable)sort __deprecated
__attribute__((deprecated("Please use `initWithProjection:sorting:`")))
     NS_SWIFT_UNAVAILABLE("Please see FindOption");


/// Options to use when executing a `find` command on a `LEGACYMongoCollection`.
/// @param limit The maximum number of documents to return. Specifying 0 will return all documents.
/// @param projection Limits the fields to return for all matching documents.
/// @param sorting The order in which to return matching documents.
- (instancetype)initWithLimit:(NSInteger)limit
                   projection:(id<LEGACYBSON> _Nullable)projection
                      sorting:(NSArray<id<LEGACYBSON>> *)sorting;

/// Options to use when executing a `find` command on a `LEGACYMongoCollection`.
/// @param projection Limits the fields to return for all matching documents.
/// @param sorting The order in which to return matching documents.
- (instancetype)initWithProjection:(id<LEGACYBSON> _Nullable)projection
                           sorting:(NSArray<id<LEGACYBSON>> *)sorting;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
