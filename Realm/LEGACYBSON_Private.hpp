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

#import <Realm/LEGACYBSON.h>
#import <realm/util/optional.hpp>

namespace realm::bson {
class Bson;
template <typename> class IndexedMap;
using BsonDocument = IndexedMap<Bson>;
}

realm::bson::Bson LEGACYConvertRLMBSONToBson(id<LEGACYBSON> b);
realm::bson::BsonDocument LEGACYConvertRLMBSONArrayToBsonDocument(NSArray<id<LEGACYBSON>> *array);
id<LEGACYBSON> LEGACYConvertBsonToRLMBSON(const realm::bson::Bson& b);
id<LEGACYBSON> LEGACYConvertBsonDocumentToRLMBSON(std::optional<realm::bson::BsonDocument> b);
NSArray<id<LEGACYBSON>> *LEGACYConvertBsonDocumentToRLMBSONArray(std::optional<realm::bson::BsonDocument> b);
