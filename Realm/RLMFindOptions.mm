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

#import "LEGACYFindOptions_Private.hpp"
#import "LEGACYBSON_Private.hpp"
#import "LEGACYCollection.h"

@interface LEGACYFindOptions() {
    realm::app::MongoCollection::FindOptions _options;
};
@end

@implementation LEGACYFindOptions

- (instancetype)initWithLimit:(NSInteger)limit
                   projection:(id<LEGACYBSON> _Nullable)projection
                         sort:(id<LEGACYBSON> _Nullable)sort {
    if (self = [super init]) {
        self.projection = projection;
        self.sort = sort;
        self.limit = limit;
    }
    return self;
}

- (instancetype)initWithProjection:(id<LEGACYBSON> _Nullable)projection
                              sort:(id<LEGACYBSON> _Nullable)sort {
    if (self = [super init]) {
        self.projection = projection;
        self.sort = sort;
    }
    return self;
}

- (instancetype)initWithLimit:(NSInteger)limit
                   projection:(id<LEGACYBSON> _Nullable)projection
                      sorting:(NSArray<id<LEGACYBSON>> *)sorting {
    if (self = [super init]) {
        self.projection = projection;
        self.sorting = sorting;
        self.limit = limit;
    }
    return self;
}

- (instancetype)initWithProjection:(id<LEGACYBSON> _Nullable)projection
                           sorting:(NSArray<id<LEGACYBSON>> *)sorting {
    if (self = [super init]) {
        self.projection = projection;
        self.sorting = sorting;
    }
    return self;
}

- (realm::app::MongoCollection::FindOptions)_findOptions {
    return _options;
}

- (id<LEGACYBSON>)projection {
    return LEGACYConvertBsonDocumentToRLMBSON(_options.projection_bson);
}

- (id<LEGACYBSON>)sort {
    return LEGACYConvertBsonDocumentToRLMBSON(_options.sort_bson);
}

- (NSArray<id<LEGACYBSON>> *)sorting {
    return LEGACYConvertBsonDocumentToRLMBSONArray(_options.sort_bson);
}

- (void)setProjection:(id<LEGACYBSON>)projection {
    if (projection) {
        auto bson = realm::bson::BsonDocument(LEGACYConvertRLMBSONToBson(projection));
        _options.projection_bson = std::optional<realm::bson::BsonDocument>(bson);
    } else {
        _options.projection_bson = realm::util::none;
    }
}

- (void)setSort:(id<LEGACYBSON>)sort {
    if (sort) {
        auto bson = realm::bson::BsonDocument(LEGACYConvertRLMBSONToBson(sort));
        _options.sort_bson = std::optional<realm::bson::BsonDocument>(bson);
    } else {
        _options.sort_bson = realm::util::none;
    }
}

- (void)setSorting:(NSArray<id<LEGACYBSON>> *)sorting {
    _options.sort_bson = LEGACYConvertRLMBSONArrayToBsonDocument(sorting);
}

- (NSInteger)limit {
    return static_cast<NSInteger>(_options.limit.value_or(0));
}

- (void)setLimit:(NSInteger)limit {
    _options.limit = std::optional<int64_t>(limit);
}

@end
