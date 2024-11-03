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

#import "LEGACYMongoCollection_Private.h"

#import "LEGACYApp_Private.hpp"
#import "LEGACYBSON_Private.hpp"
#import "LEGACYError_Private.hpp"
#import "LEGACYFindOneAndModifyOptions_Private.hpp"
#import "LEGACYFindOptions_Private.hpp"
#import "LEGACYNetworkTransport_Private.hpp"
#import "LEGACYUpdateResult_Private.hpp"
#import "LEGACYUser_Private.hpp"

#import <realm/object-store/sync/mongo_client.hpp>
#import <realm/object-store/sync/mongo_collection.hpp>
#import <realm/object-store/sync/mongo_database.hpp>

__attribute__((objc_direct_members))
@implementation LEGACYChangeStream {
@public
    realm::app::WatchStream _watchStream;
    id<LEGACYChangeEventDelegate> _subscriber;
    __weak NSURLSession *_session;
    void (^_schedule)(dispatch_block_t);
}

- (instancetype)initWithChangeEventSubscriber:(id<LEGACYChangeEventDelegate>)subscriber
                                    scheduler:(void (^)(dispatch_block_t))scheduler {
    if (self = [super init]) {
        _subscriber = subscriber;
        _schedule = scheduler;
    }
    return self;
}

- (void)didCloseWithError:(NSError *)error {
    _schedule(^{
        [_subscriber changeStreamDidCloseWithError:error];
    });
}

- (void)didOpen {
    _schedule(^{
        [_subscriber changeStreamDidOpen:self];
    });
}

- (void)didReceiveError:(nonnull NSError *)error {
    _schedule(^{
        [_subscriber changeStreamDidReceiveError:error];
    });
}

- (void)didReceiveEvent:(nonnull NSData *)event {
    if (_watchStream.state() == realm::app::WatchStream::State::NEED_DATA) {
        [event enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *) {
            _watchStream.feed_buffer(std::string_view(static_cast<const char *>(bytes), byteRange.length));
        }];
    }

    while (_watchStream.state() == realm::app::WatchStream::State::HAVE_EVENT) {
        id<LEGACYBSON> event = LEGACYConvertBsonToRLMBSON(_watchStream.next_event());
        _schedule(^{
            [_subscriber changeStreamDidReceiveChangeEvent:event];
        });
    }

    if (_watchStream.state() == realm::app::WatchStream::State::HAVE_ERROR) {
        [self didReceiveError:makeError(_watchStream.error())];
    }
}

- (void)attachURLSession:(NSURLSession *)urlSession {
    _session = urlSession;
}

- (void)close {
    [_session invalidateAndCancel];
}
@end

static realm::bson::BsonDocument toBsonDocument(id<LEGACYBSON> bson) {
    return realm::bson::BsonDocument(LEGACYConvertRLMBSONToBson(bson));
}
static realm::bson::BsonArray toBsonArray(id<LEGACYBSON> bson) {
    return realm::bson::BsonArray(LEGACYConvertRLMBSONToBson(bson));
}

__attribute__((objc_direct_members))
@interface LEGACYMongoCollection ()
@property (nonatomic, strong) LEGACYUser *user;
@property (nonatomic, strong) NSString *serviceName;
@property (nonatomic, strong) NSString *databaseName;
@end

__attribute__((objc_direct_members))
@implementation LEGACYMongoCollection
- (instancetype)initWithUser:(LEGACYUser *)user
                 serviceName:(NSString *)serviceName
                databaseName:(NSString *)databaseName
              collectionName:(NSString *)collectionName {
    if (self = [super init]) {
        _user = user;
        _serviceName = serviceName;
        _databaseName = databaseName;
        _name = collectionName;
    }
    return self;
}

- (realm::app::MongoCollection)collection:(NSString *)name {
    return _user._syncUser->mongo_client(self.serviceName.UTF8String)
        .db(self.databaseName.UTF8String).collection(name.UTF8String);
}

- (realm::app::MongoCollection)collection {
    return [self collection:self.name];
}

- (void)findWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
          options:(LEGACYFindOptions *)options
       completion:(LEGACYMongoFindBlock)completion {
    self.collection.find(toBsonDocument(document), [options _findOptions],
                         [completion](std::optional<realm::bson::BsonArray> documents,
                                      std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        completion((NSArray<NSDictionary<NSString *, id<LEGACYBSON>> *> *)LEGACYConvertBsonToRLMBSON(*documents), nil);
    });
}

- (void)findWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
       completion:(LEGACYMongoFindBlock)completion {
    [self findWhere:document options:[[LEGACYFindOptions alloc] init] completion:completion];
}

- (void)findOneDocumentWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
                     options:(LEGACYFindOptions *)options
                  completion:(LEGACYMongoFindOneBlock)completion {
    self.collection.find_one(toBsonDocument(document), [options _findOptions],
                             [completion](std::optional<realm::bson::BsonDocument> document,
                                          std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        if (document) {
            completion((NSDictionary<NSString *, id<LEGACYBSON>> *)LEGACYConvertBsonToRLMBSON(*document), nil);
        } else {
            completion(nil, nil);
        }
    });
}

- (void)findOneDocumentWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
                  completion:(LEGACYMongoFindOneBlock)completion {
    [self findOneDocumentWhere:document options:[[LEGACYFindOptions alloc] init] completion:completion];
}

- (void)insertOneDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
               completion:(LEGACYMongoInsertBlock)completion {
    self.collection.insert_one(toBsonDocument(document),
                               [completion](std::optional<realm::bson::Bson> objectId,
                                            std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        completion(LEGACYConvertBsonToRLMBSON(*objectId), nil);
    });
}

- (void)insertManyDocuments:(NSArray<NSDictionary<NSString *, id<LEGACYBSON>> *> *)documents
                 completion:(LEGACYMongoInsertManyBlock)completion {
    self.collection.insert_many(toBsonArray(documents),
                                [completion](std::vector<realm::bson::Bson> insertedIds,
                                             std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        NSMutableArray *insertedArr = [[NSMutableArray alloc] initWithCapacity:insertedIds.size()];
        for (auto& objectId : insertedIds) {
            [insertedArr addObject:LEGACYConvertBsonToRLMBSON(objectId)];
        }
        completion(insertedArr, nil);
    });
}

- (void)aggregateWithPipeline:(NSArray<NSDictionary<NSString *, id<LEGACYBSON>> *> *)pipeline
                   completion:(LEGACYMongoFindBlock)completion {
    self.collection.aggregate(toBsonArray(pipeline),
                              [completion](std::optional<realm::bson::BsonArray> documents,
                                           std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        completion((NSArray<id> *)LEGACYConvertBsonToRLMBSON(*documents), nil);
    });
}

- (void)countWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
             limit:(NSInteger)limit
        completion:(LEGACYMongoCountBlock)completion {
    self.collection.count_bson(toBsonDocument(document), limit,
                               [completion](std::optional<realm::bson::Bson>&& value,
                                            std::optional<realm::app::AppError>&& error) {
        if (error) {
            return completion(0, makeError(*error));
        }
        if (value->type() == realm::bson::Bson::Type::Int64) {
            return completion(static_cast<NSInteger>(static_cast<int64_t>(*value)), nil);
        }
        // If the collection does not exist the call returns undefined
        return completion(0, nil);
    });
}

- (void)countWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
        completion:(LEGACYMongoCountBlock)completion {
    [self countWhere:document limit:0 completion:completion];
}

- (void)deleteOneDocumentWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
                    completion:(LEGACYMongoCountBlock)completion {
    self.collection.delete_one(toBsonDocument(document),
                               [completion](uint64_t count,
                                            std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(0, makeError(*error));
        }
        completion(static_cast<NSInteger>(count), nil);
    });
}

- (void)deleteManyDocumentsWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)document
                      completion:(LEGACYMongoCountBlock)completion {
    self.collection.delete_many(toBsonDocument(document),
                                [completion](uint64_t count,
                                             std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(0, makeError(*error));
        }
        completion(static_cast<NSInteger>(count), nil);
    });
}

- (void)updateOneDocumentWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
                updateDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)updateDocument
                        upsert:(BOOL)upsert
                    completion:(LEGACYMongoUpdateBlock)completion {
    self.collection.update_one(toBsonDocument(filterDocument), toBsonDocument(updateDocument),
                               upsert,
                               [completion](realm::app::MongoCollection::UpdateResult result,
                                            std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        completion([[LEGACYUpdateResult alloc] initWithUpdateResult:result], nil);
    });
}

- (void)updateOneDocumentWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
                updateDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)updateDocument
                    completion:(LEGACYMongoUpdateBlock)completion {
    [self updateOneDocumentWhere:filterDocument
                  updateDocument:updateDocument
                          upsert:NO
                      completion:completion];
}

- (void)updateManyDocumentsWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
                  updateDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)updateDocument
                          upsert:(BOOL)upsert
                      completion:(LEGACYMongoUpdateBlock)completion {
    self.collection.update_many(toBsonDocument(filterDocument), toBsonDocument(updateDocument),
                                upsert,
                                [completion](realm::app::MongoCollection::UpdateResult result,
                                             std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        completion([[LEGACYUpdateResult alloc] initWithUpdateResult:result], nil);
    });
}

- (void)updateManyDocumentsWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
                  updateDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)updateDocument
                      completion:(LEGACYMongoUpdateBlock)completion {
    [self updateManyDocumentsWhere:filterDocument
                    updateDocument:updateDocument
                            upsert:NO
                        completion:completion];
}

- (void)findOneAndUpdateWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
               updateDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)updateDocument
                      options:(LEGACYFindOneAndModifyOptions *)options
                   completion:(LEGACYMongoFindOneBlock)completion {
    self.collection.find_one_and_update(toBsonDocument(filterDocument), toBsonDocument(updateDocument),
                                        [options _findOneAndModifyOptions],
                                        [completion](std::optional<realm::bson::BsonDocument> document,
                                                     std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }

        return completion((NSDictionary *)LEGACYConvertBsonDocumentToRLMBSON(document), nil);
    });
}

- (void)findOneAndUpdateWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
               updateDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)updateDocument
                   completion:(LEGACYMongoFindOneBlock)completion {
    [self findOneAndUpdateWhere:filterDocument
                 updateDocument:updateDocument
                        options:[[LEGACYFindOneAndModifyOptions alloc] init]
                     completion:completion];
}

- (void)findOneAndReplaceWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
           replacementDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)replacementDocument
                       options:(LEGACYFindOneAndModifyOptions *)options
                    completion:(LEGACYMongoFindOneBlock)completion {
    self.collection.find_one_and_replace(toBsonDocument(filterDocument), toBsonDocument(replacementDocument),
                                         [options _findOneAndModifyOptions],
                                         [completion](std::optional<realm::bson::BsonDocument> document,
                                                      std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }

        return completion((NSDictionary *)LEGACYConvertBsonDocumentToRLMBSON(document), nil);
    });
}

- (void)findOneAndReplaceWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
           replacementDocument:(NSDictionary<NSString *, id<LEGACYBSON>> *)replacementDocument
                    completion:(LEGACYMongoFindOneBlock)completion {
    [self findOneAndReplaceWhere:filterDocument
             replacementDocument:replacementDocument
                         options:[[LEGACYFindOneAndModifyOptions alloc] init]
                      completion:completion];
}

- (void)findOneAndDeleteWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
                      options:(LEGACYFindOneAndModifyOptions *)options
                   completion:(LEGACYMongoDeleteBlock)completion {
    self.collection.find_one_and_delete(toBsonDocument(filterDocument),
                                        [options _findOneAndModifyOptions],
                                        [completion](std::optional<realm::bson::BsonDocument> document,
                                                     std::optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }

        return completion((NSDictionary *)LEGACYConvertBsonDocumentToRLMBSON(document), nil);
    });
}

- (void)findOneAndDeleteWhere:(NSDictionary<NSString *, id<LEGACYBSON>> *)filterDocument
                   completion:(LEGACYMongoDeleteBlock)completion {
    [self findOneAndDeleteWhere:filterDocument
                        options:[[LEGACYFindOneAndModifyOptions alloc] init]
                     completion:completion];
}

- (LEGACYChangeStream *)watchWithDelegate:(id<LEGACYChangeEventDelegate>)delegate
                         delegateQueue:(nullable dispatch_queue_t)delegateQueue {
    return [self watchWithMatchFilter:nil
                             idFilter:nil
                             delegate:delegate
                        delegateQueue:delegateQueue];
}

- (LEGACYChangeStream *)watchWithFilterIds:(NSArray<LEGACYObjectId *> *)filterIds
                               delegate:(id<LEGACYChangeEventDelegate>)delegate
                          delegateQueue:(nullable dispatch_queue_t)delegateQueue {
    return [self watchWithMatchFilter:nil
                             idFilter:filterIds
                             delegate:delegate
                        delegateQueue:delegateQueue];
}

- (LEGACYChangeStream *)watchWithMatchFilter:(NSDictionary<NSString *, id<LEGACYBSON>> *)matchFilter
                                 delegate:(id<LEGACYChangeEventDelegate>)delegate
                            delegateQueue:(nullable dispatch_queue_t)delegateQueue {
    return [self watchWithMatchFilter:matchFilter
                             idFilter:nil
                             delegate:delegate
                        delegateQueue:delegateQueue];
}

- (LEGACYChangeStream *)watchWithMatchFilter:(nullable id<LEGACYBSON>)matchFilter
                                 idFilter:(nullable id<LEGACYBSON>)idFilter
                                 delegate:(id<LEGACYChangeEventDelegate>)delegate
                            delegateQueue:(nullable dispatch_queue_t)queue {
    queue = queue ?: dispatch_get_main_queue();
    return [self watchWithMatchFilter:matchFilter
                             idFilter:idFilter
                             delegate:delegate
                            scheduler:^(dispatch_block_t block) { dispatch_async(queue, block); }];
}

- (LEGACYChangeStream *)watchWithMatchFilter:(nullable id<LEGACYBSON>)matchFilter
                                 idFilter:(nullable id<LEGACYBSON>)idFilter
                                 delegate:(id<LEGACYChangeEventDelegate>)delegate
                                scheduler:(void (^)(dispatch_block_t))scheduler {
    realm::bson::BsonDocument baseArgs = {
        {"database", self.databaseName.UTF8String},
        {"collection", self.name.UTF8String}
    };

    if (matchFilter) {
        baseArgs["filter"] = LEGACYConvertRLMBSONToBson(matchFilter);
    }
    if (idFilter) {
        baseArgs["ids"] = LEGACYConvertRLMBSONToBson(idFilter);
    }
    auto args = realm::bson::BsonArray{baseArgs};
    auto app = self.user.app._realmApp;
    auto request = app->make_streaming_request(app->current_user(), "watch", args,
                                               std::optional<std::string>(self.serviceName.UTF8String));
    auto changeStream = [[LEGACYChangeStream alloc] initWithChangeEventSubscriber:delegate scheduler:scheduler];
    LEGACYNetworkTransport *transport = self.user.app.configuration.transport;
    LEGACYRequest *rlmRequest = LEGACYRequestFromRequest(request);
    changeStream->_session = [transport doStreamRequest:rlmRequest eventSubscriber:changeStream];
    return changeStream;
}
@end
