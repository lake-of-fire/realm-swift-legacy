////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
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

#import "LEGACYSyncSubscription_Private.hpp"

#import "LEGACYAsyncTask_Private.h"
#import "LEGACYError_Private.hpp"
#import "LEGACYObjectId_Private.hpp"
#import "LEGACYQueryUtil.hpp"
#import "LEGACYRealm_Private.hpp"
#import "LEGACYScheduler.h"
#import "LEGACYUtil.hpp"

#import <realm/sync/subscriptions.hpp>
#import <realm/status_with.hpp>
#import <realm/util/future.hpp>

#pragma mark - Subscription

@interface LEGACYSyncSubscription () {
    std::unique_ptr<realm::sync::Subscription> _subscription;
    LEGACYSyncSubscriptionSet *_subscriptionSet;
}
@end

@implementation LEGACYSyncSubscription

- (instancetype)initWithSubscription:(realm::sync::Subscription)subscription subscriptionSet:(LEGACYSyncSubscriptionSet *)subscriptionSet {
    if (self = [super init]) {
        _subscription = std::make_unique<realm::sync::Subscription>(subscription);
        _subscriptionSet = subscriptionSet;
        return self;
    }
    return nil;
}

- (LEGACYObjectId *)identifier {
    return [[LEGACYObjectId alloc] initWithValue:_subscription->id];
}

- (nullable NSString *)name {
    auto name = _subscription->name;
    if (name) {
        return @(name->c_str());
    }
    return nil;
}

- (NSDate *)createdAt {
    return LEGACYTimestampToNSDate(_subscription->created_at);
}

- (NSDate *)updatedAt {
    return LEGACYTimestampToNSDate(_subscription->updated_at);
}

- (NSString *)queryString {
    return @(_subscription->query_string.c_str());
}

- (NSString *)objectClassName {
    return @(_subscription->object_class_name.c_str());
}

- (void)updateSubscriptionWhere:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    [self updateSubscriptionWhere:predicateFormat
                             args:args];
    va_end(args);
}

- (void)updateSubscriptionWhere:(NSString *)predicateFormat
                           args:(va_list)args {
    [self updateSubscriptionWithPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (void)updateSubscriptionWithPredicate:(NSPredicate *)predicate {
    if (self.name != nil) {
        [_subscriptionSet addSubscriptionWithClassName:self.objectClassName
                                      subscriptionName:self.name
                                             predicate:predicate
                                        updateExisting:true];
    }
    else {
        LEGACYSyncSubscription *foundSubscription = [_subscriptionSet subscriptionWithClassName:self.objectClassName where:self.queryString];
        if (foundSubscription) {
            [_subscriptionSet removeSubscription:foundSubscription];
            [_subscriptionSet addSubscriptionWithClassName:self.objectClassName
                                                 predicate:predicate];
        } else {
            @throw LEGACYException(@"Cannot update a non-existent subscription.");
        }
    }
}

@end

#pragma mark - SubscriptionSet

@interface LEGACYSyncSubscriptionSet () {
    std::unique_ptr<realm::sync::MutableSubscriptionSet> _mutableSubscriptionSet;
    NSHashTable<LEGACYSyncSubscriptionEnumerator *> *_enumerators;
}
@end

@interface LEGACYSyncSubscriptionEnumerator() {
    // The buffer supplied by fast enumeration does not retain the objects given
    // to it, but because we create objects on-demand and don't want them
    // autoreleased (a table can have more rows than the device has memory for
    // accessor objects) we need a thing to retain them.
    id _strongBuffer[16];
}
@end

@implementation LEGACYSyncSubscriptionEnumerator

- (instancetype)initWithSubscriptionSet:(LEGACYSyncSubscriptionSet *)subscriptionSet {
    if (self = [super init]) {
        _subscriptionSet = subscriptionSet;
        return self;
    }
    return nil;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len {
    NSUInteger batchCount = 0, count = [_subscriptionSet count];
    for (NSUInteger index = state->state; index < count && batchCount < len; ++index) {
        auto subscription = [_subscriptionSet objectAtIndex:index];
        _strongBuffer[batchCount] = subscription;
        batchCount++;
    }

    for (NSUInteger i = batchCount; i < len; ++i) {
        _strongBuffer[i] = nil;
    }

    if (batchCount == 0) {
        // Release our data if we're done, as we're autoreleased and so may
        // stick around for a while
        if (_subscriptionSet) {
            _subscriptionSet = nil;
        }
    }


    state->itemsPtr = (__unsafe_unretained id *)(void *)_strongBuffer;
    state->state += batchCount;
    state->mutationsPtr = state->extra+1;

    return batchCount;
}

@end

NSUInteger LEGACYFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            LEGACYSyncSubscriptionSet *collection) {
    __autoreleasing LEGACYSyncSubscriptionEnumerator *enumerator;
    if (state->state == 0) {
        enumerator = collection.fastEnumerator;
        state->extra[0] = (long)enumerator;
        state->extra[1] = collection.count;
    }
    else {
        enumerator = (__bridge id)(void *)state->extra[0];
    }

    return [enumerator countByEnumeratingWithState:state count:len];
}

@implementation LEGACYSyncSubscriptionSet {
    std::mutex _collectionEnumeratorMutex;
    LEGACYRealm *_realm;
}

- (instancetype)initWithSubscriptionSet:(realm::sync::SubscriptionSet)subscriptionSet
                                  realm:(LEGACYRealm *)realm {
    if (self = [super init]) {
        _subscriptionSet = std::make_unique<realm::sync::SubscriptionSet>(subscriptionSet);
        _realm = realm;
        return self;
    }
    return nil;
}

- (LEGACYSyncSubscriptionEnumerator *)fastEnumerator {
    return [[LEGACYSyncSubscriptionEnumerator alloc] initWithSubscriptionSet:self];
}

- (NSUInteger)count {
    return _subscriptionSet->size();
}

- (nullable NSError *)error {
    _subscriptionSet->refresh();
    NSString *errorMessage = LEGACYStringDataToNSString(_subscriptionSet->error_str());
    if (errorMessage.length == 0) {
        return nil;
    }
    return [[NSError alloc] initWithDomain:LEGACYSyncErrorDomain
                                      code:LEGACYSyncErrorInvalidFlexibleSyncSubscriptions
                                  userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
}

- (LEGACYSyncSubscriptionState)state {
    _subscriptionSet->refresh();
    switch (_subscriptionSet->state()) {
        case realm::sync::SubscriptionSet::State::Uncommitted:
        case realm::sync::SubscriptionSet::State::Pending:
        case realm::sync::SubscriptionSet::State::Bootstrapping:
        case realm::sync::SubscriptionSet::State::AwaitingMark:
            return LEGACYSyncSubscriptionStatePending;
        case realm::sync::SubscriptionSet::State::Complete:
            return LEGACYSyncSubscriptionStateComplete;
        case realm::sync::SubscriptionSet::State::Error:
            return LEGACYSyncSubscriptionStateError;
        case realm::sync::SubscriptionSet::State::Superseded:
            return LEGACYSyncSubscriptionStateSuperseded;
    }
}

#pragma mark - Batch Update subscriptions

- (void)update:(__attribute__((noescape)) void(^)(void))block {
    [self update:block onComplete:nil];
}

- (void)update:(__attribute__((noescape)) void(^)(void))block onComplete:(void(^)(NSError *))completionBlock {
    [self update:block queue:nil onComplete:completionBlock];
}

- (void)update:(__attribute__((noescape)) void(^)(void))block
         queue:(nullable dispatch_queue_t)queue
    onComplete:(void(^)(NSError *))completionBlock {
    [self update:block queue:queue timeout:0 onComplete:completionBlock];
}

- (void)update:(__attribute__((noescape)) void(^)(void))block
         queue:(nullable dispatch_queue_t)queue
       timeout:(NSTimeInterval)timeout
    onComplete:(void(^)(NSError *))completionBlock {
    if (_mutableSubscriptionSet) {
        @throw LEGACYException(@"Cannot initiate a write transaction on subscription set that is already being updated.");
    }
    _mutableSubscriptionSet = std::make_unique<realm::sync::MutableSubscriptionSet>(_subscriptionSet->make_mutable_copy());
    realm::util::ScopeExit cleanup([&]() noexcept {
        if (_mutableSubscriptionSet) {
            _mutableSubscriptionSet = nullptr;
            _subscriptionSet->refresh();
        }
    });

    block();

    try {
        _subscriptionSet = std::make_unique<realm::sync::SubscriptionSet>(std::move(*_mutableSubscriptionSet).commit());
        _mutableSubscriptionSet = nullptr;
    }
    catch (realm::Exception const& ex) {
        @throw LEGACYException(ex);
    }
    catch (std::exception const& ex) {
        @throw LEGACYException(ex);
    }

    if (completionBlock) {
        [self waitForSynchronizationOnQueue:queue
                                    timeout:timeout
                            completionBlock:completionBlock];
    }
}

- (void)waitForSynchronizationOnQueue:(nullable dispatch_queue_t)queue
                              timeout:(NSTimeInterval)timeout
                      completionBlock:(void(^)(NSError *))completionBlock {
    LEGACYAsyncSubscriptionTask *syncSubscriptionTask = [[LEGACYAsyncSubscriptionTask alloc] initWithSubscriptionSet:self
                                                                                                         queue:queue
                                                                                                       timeout:timeout
                                                                                                    completion:completionBlock];
    [syncSubscriptionTask waitForSubscription];
}

#pragma mark - Find subscription

- (nullable LEGACYSyncSubscription *)subscriptionWithName:(NSString *)name {
    auto subscription = _subscriptionSet->find([name UTF8String]);
    if (subscription) {
        return [[LEGACYSyncSubscription alloc] initWithSubscription:*subscription
                                                 subscriptionSet:self];
    }
    return nil;
}

- (nullable LEGACYSyncSubscription *)subscriptionWithClassName:(NSString *)objectClassName
                                                      where:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    return [self subscriptionWithClassName:objectClassName
                                     where:predicateFormat
                                      args:args];
    va_end(args);
}

- (nullable LEGACYSyncSubscription *)subscriptionWithClassName:(NSString *)objectClassName
                                                      where:(NSString *)predicateFormat
                                                       args:(va_list)args {
    return [self subscriptionWithClassName:objectClassName
                                 predicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (nullable LEGACYSyncSubscription *)subscriptionWithClassName:(NSString *)objectClassName
                                                  predicate:(NSPredicate *)predicate {
    LEGACYClassInfo& info = _realm->_info[objectClassName];
    auto query = LEGACYPredicateToQuery(predicate, info.rlmObjectSchema, _realm.schema, _realm.group);
    return [self subscriptionWithQuery:query];
}

- (nullable LEGACYSyncSubscription *)subscriptionWithQuery:(realm::Query)query {
    auto subscription = _subscriptionSet->find(query);
    if (subscription) {
        return [[LEGACYSyncSubscription alloc] initWithSubscription:*subscription
                                                 subscriptionSet:self];
    }
    return nil;
}

- (nullable LEGACYSyncSubscription *)subscriptionWithName:(NSString *)name
                                                 query:(realm::Query)query {
    auto subscription = _subscriptionSet->find([name UTF8String]);
    if (subscription && subscription->query_string == query.get_description()) {
        return [[LEGACYSyncSubscription alloc] initWithSubscription:*subscription
                                                 subscriptionSet:self];
    } else {
        return nil;
    }
}


#pragma mark - Add a Subscription

- (void)addSubscriptionWithClassName:(NSString *)objectClassName
                               where:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    return [self addSubscriptionWithClassName:objectClassName
                                        where:predicateFormat
                                         args:args];
    va_end(args);
}

- (void)addSubscriptionWithClassName:(NSString *)objectClassName
                               where:(NSString *)predicateFormat
                                args:(va_list)args {
    [self addSubscriptionWithClassName:objectClassName
                      subscriptionName:nil
                             predicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (void)addSubscriptionWithClassName:(NSString *)objectClassName
                    subscriptionName:(NSString *)name
                               where:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    return [self addSubscriptionWithClassName:objectClassName
                             subscriptionName:name
                                        where:predicateFormat
                                         args:args];
    va_end(args);
}

- (void)addSubscriptionWithClassName:(NSString *)objectClassName
                    subscriptionName:(NSString *)name
                               where:(NSString *)predicateFormat
                                args:(va_list)args {
    [self addSubscriptionWithClassName:objectClassName
                      subscriptionName:name
                             predicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
    
}

- (void)addSubscriptionWithClassName:(NSString *)objectClassName
                           predicate:(NSPredicate *)predicate {
    return [self addSubscriptionWithClassName:objectClassName
                             subscriptionName:nil
                                    predicate:predicate];
}

- (void)addSubscriptionWithClassName:(NSString *)objectClassName
                    subscriptionName:(nullable NSString *)name
                           predicate:(NSPredicate *)predicate {
    return [self addSubscriptionWithClassName:objectClassName
                             subscriptionName:name
                                    predicate:predicate
                               updateExisting:false];
}

- (void)addSubscriptionWithClassName:(NSString *)objectClassName
                    subscriptionName:(nullable NSString *)name
                           predicate:(NSPredicate *)predicate
                      updateExisting:(BOOL)updateExisting {
    [self verifyInWriteTransaction];

    LEGACYClassInfo& info = _realm->_info[objectClassName];
    auto query = LEGACYPredicateToQuery(predicate, info.rlmObjectSchema, _realm.schema, _realm.group);

    [self addSubscriptionWithClassName:objectClassName
                      subscriptionName:name
                                 query:query
                        updateExisting:updateExisting];
}

- (LEGACYObjectId *)addSubscriptionWithClassName:(NSString *)objectClassName
                             subscriptionName:(nullable NSString *)name
                                        query:(realm::Query)query
                               updateExisting:(BOOL)updateExisting {
    [self verifyInWriteTransaction];

    if (name) {
        if (updateExisting || !_mutableSubscriptionSet->find(name.UTF8String)) {
            auto it = _mutableSubscriptionSet->insert_or_assign(name.UTF8String, query);
            return [[LEGACYObjectId alloc] initWithValue:it.first->id];
        }
        else {
            @throw LEGACYException(@"A subscription named '%@' already exists. If you meant to update the existing subscription please use the `update` method.", name);
        }
    }
    else {
        auto it = _mutableSubscriptionSet->insert_or_assign(query);
        return [[LEGACYObjectId alloc] initWithValue:it.first->id];
    }
}

#pragma mark - Remove Subscription

- (void)removeSubscriptionWithName:(NSString *)name {
    [self verifyInWriteTransaction];

    auto subscription = _subscriptionSet->find([name UTF8String]);
    if (subscription) {
        _mutableSubscriptionSet->erase(subscription->name);
    }
}

- (void)removeSubscriptionWithClassName:(NSString *)objectClassName
                                  where:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    [self removeSubscriptionWithClassName:objectClassName
                                    where:predicateFormat
                                     args:args];
    va_end(args);
}

- (void)removeSubscriptionWithClassName:(NSString *)objectClassName
                                  where:(NSString *)predicateFormat
                                   args:(va_list)args {
    [self removeSubscriptionWithClassName:objectClassName
                                predicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (void)removeSubscriptionWithClassName:(NSString *)objectClassName
                              predicate:(NSPredicate *)predicate {
    LEGACYClassInfo& info = _realm->_info[objectClassName];
    auto query = LEGACYPredicateToQuery(predicate, info.rlmObjectSchema, _realm.schema, _realm.group);
    [self removeSubscriptionWithClassName:objectClassName query:query];
}

- (void)removeSubscriptionWithClassName:(NSString *)objectClassName
                                  query:(realm::Query)query {
    [self verifyInWriteTransaction];

    auto subscription = _subscriptionSet->find(query);
    if (subscription) {
        _mutableSubscriptionSet->erase(query);
    }
}

- (void)removeSubscription:(LEGACYSyncSubscription *)subscription {
    [self removeSubscriptionWithId:subscription.identifier];
}

- (void)removeSubscriptionWithId:(LEGACYObjectId *)objectId {
    [self verifyInWriteTransaction];

    for (auto it = _mutableSubscriptionSet->begin(); it != _mutableSubscriptionSet->end();) {
        if (it->id == objectId.value) {
            it = _mutableSubscriptionSet->erase(it);
            return;
        }
        it++;
    }
}

#pragma mark - Remove Subscriptions

- (void)removeAllSubscriptions {
    [self verifyInWriteTransaction];
    _mutableSubscriptionSet->clear();
}

- (void)removeAllUnnamedSubscriptions {
    [self verifyInWriteTransaction];

    for (auto it = _mutableSubscriptionSet->begin(); it != _mutableSubscriptionSet->end();) {
        if (!it->name) {
            it = _mutableSubscriptionSet->erase(it);
        } else {
            it++;
        }
    }
}

- (void)removeAllSubscriptionsWithClassName:(NSString *)className {
    [self verifyInWriteTransaction];
    
    for (auto it = _mutableSubscriptionSet->begin(); it != _mutableSubscriptionSet->end();) {
        if (it->object_class_name == [className UTF8String]) {
            it = _mutableSubscriptionSet->erase(it);
        }
        else {
            it++;
        }
    }
}

#pragma mark - NSFastEnumerator

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return LEGACYFastEnumerate(state, len, self);
}

#pragma mark - SubscriptionSet Collection

- (LEGACYSyncSubscription *)objectAtIndex:(NSUInteger)index {
    auto size = _subscriptionSet->size();
    if (index >= size) {
        @throw LEGACYException(@"Index %llu is out of bounds (must be less than %llu).",
                            (unsigned long long)index, (unsigned long long)size);
    }
    
    return [[LEGACYSyncSubscription alloc]initWithSubscription:_subscriptionSet->at(size_t(index))
                                            subscriptionSet:self];
}

- (LEGACYSyncSubscription *)firstObject {
    if (_subscriptionSet->size() < 1) {
        return nil;
    }
    return [[LEGACYSyncSubscription alloc]initWithSubscription:_subscriptionSet->at(size_t(0))
                                            subscriptionSet:self];
}

- (LEGACYSyncSubscription *)lastObject {
    if (_subscriptionSet->size() < 1) {
        return nil;
    }
    
    return [[LEGACYSyncSubscription alloc]initWithSubscription:_subscriptionSet->at(_subscriptionSet->size()-1)
                                            subscriptionSet:self];
}

#pragma mark - Subscript

- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

#pragma mark - Private API

- (uint64_t)version {
    return _subscriptionSet->version();
}

- (void)verifyInWriteTransaction {
    if (_mutableSubscriptionSet == nil) {
        @throw LEGACYException(@"Can only add, remove, or update subscriptions within a write subscription block.");
    }
}

@end
