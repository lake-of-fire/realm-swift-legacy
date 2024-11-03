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

#import "LEGACYSyncTestCase.h"
#import "LEGACYSyncSubscription_Private.h"
#import "LEGACYApp_Private.hpp"

@interface LEGACYSubscriptionTests : LEGACYSyncTestCase
@end

@implementation LEGACYSubscriptionTests
- (NSArray *)defaultObjectTypes {
    return @[Dog.self, Person.self];
}

- (NSString *)createAppWithError:(NSError **)error {
    return [self createFlexibleSyncAppWithError:error];
}

- (LEGACYRealmConfiguration *)configurationForUser:(LEGACYUser *)user {
    return [user flexibleSyncConfiguration];
}

- (void)testCreateFlexibleSyncApp {
    NSString *appId = [RealmServer.shared createAppWithFields:@[@"age"]
                                                        types:@[Person.self]
                                                   persistent:false
                                                        error:nil];
    LEGACYApp *app = [self appWithId:appId];
    XCTAssertNotNil(app);
}

- (void)testFlexibleSyncOpenRealm {
    XCTAssertNotNil([self openRealm]);
}

- (void)testGetSubscriptionsWhenLocalRealm {
    LEGACYRealmConfiguration *configuration = [LEGACYRealmConfiguration defaultConfiguration];
    configuration.objectClasses = @[Person.self];
    LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:configuration error:nil];
    LEGACYAssertThrowsWithReason(realm.subscriptions, @"This Realm was not configured with flexible sync");
}

- (void)testGetSubscriptionsWhenPbsRealm {
    LEGACYRealmConfiguration *config = [self.createUser configurationWithPartitionValue:nil];
    config.objectClasses = @[];
    LEGACYRealm *realm = [LEGACYRealm realmWithConfiguration:config error:nil];
    LEGACYAssertThrowsWithReason(realm.subscriptions, @"This Realm was not configured with flexible sync");
}

- (void)testFlexibleSyncRealmFilePath {
    LEGACYUser *user = [self createUser];
    LEGACYRealmConfiguration *config = [user flexibleSyncConfiguration];
    NSString *expected = [NSString stringWithFormat:@"mongodb-realm/%@/%@/flx_sync_default.realm", self.appId, user.identifier];
    XCTAssertTrue([config.fileURL.path hasSuffix:expected]);
}

- (void)testGetSubscriptionsWhenFlexibleSync {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;
    XCTAssertNotNil(subs);
    XCTAssertEqual(subs.version, 0UL);
    XCTAssertEqual(subs.count, 0UL);
}

- (void)testGetSubscriptionsWhenSameVersion {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs1 = realm.subscriptions;
    LEGACYSyncSubscriptionSet *subs2 = realm.subscriptions;
    XCTAssertEqual(subs1.version, 0UL);
    XCTAssertEqual(subs2.version, 0UL);
}

- (void)testCheckVersionAfterAddSubscription {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;
    XCTAssertNotNil(subs);
    XCTAssertEqual(subs.version, 0UL);
    XCTAssertEqual(subs.count, 0UL);

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                                     where:@"age > 15"];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);
}

- (void)testEmptyWriteSubscriptions {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;
    XCTAssertNotNil(subs);
    XCTAssertEqual(subs.version, 0UL);
    XCTAssertEqual(subs.count, 0UL);

    [subs update:^{}];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 0UL);
}

- (void)testAddAndFindSubscriptionByQuery {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                                     where:@"age > 15"];
    }];

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithClassName:Person.className
                                                                       where:@"age > 15"];
    XCTAssertNotNil(foundSubscription);
    XCTAssertNil(foundSubscription.name);
    XCTAssert(foundSubscription.queryString, @"age > 15");
}

- (void)testAddAndFindSubscriptionWithCompoundQuery {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;
    XCTAssertNotNil(subs);
    XCTAssertEqual(subs.version, 0UL);
    XCTAssertEqual(subs.count, 0UL);

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                                     where:@"firstName == %@ and lastName == %@", @"John", @"Doe"];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithClassName:Person.className
                                                                       where:@"firstName == %@ and lastName == %@", @"John", @"Doe"];
    XCTAssertNotNil(foundSubscription);
    XCTAssertNil(foundSubscription.name);
    XCTAssert(foundSubscription.queryString, @"firstName == 'John' and lastName == 'Doe'");
}

- (void)testAddAndFindSubscriptionWithPredicate {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;
    XCTAssertNotNil(subs);
    XCTAssertEqual(subs.version, 0UL);
    XCTAssertEqual(subs.count, 0UL);

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                                 predicate:[NSPredicate predicateWithFormat:@"age == %d", 20]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithClassName:Person.className
                                                                   predicate:[NSPredicate predicateWithFormat:@"age == %d", 20]];
    XCTAssertNotNil(foundSubscription);
    XCTAssertNil(foundSubscription.name);
    XCTAssert(foundSubscription.queryString, @"age == 20");
}

- (void)testAddSubscriptionWithoutWriteThrow {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;
    LEGACYAssertThrowsWithReason([subs addSubscriptionWithClassName:Person.className where:@"age > 15"],
                              @"Can only add, remove, or update subscriptions within a write subscription block.");
}

- (void)testAddAndFindSubscriptionByName {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;
    XCTAssertNotNil(realm.subscriptions);
    XCTAssertEqual(realm.subscriptions.version, 0UL);
    XCTAssertEqual(realm.subscriptions.count, 0UL);

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_older_15"
                                     where:@"age > 15"];
    }];

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_older_15"];
    XCTAssertNotNil(foundSubscription);
    XCTAssert(foundSubscription.name, @"person_older_15");
    XCTAssert(foundSubscription.queryString, @"age > 15");
}

- (void)testAddDuplicateSubscription {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Person.className
                                     where:@"age > 15"];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);
}

- (void)testAddDuplicateNamedSubscriptionWillThrow {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age"
                                     where:@"age > 15"];
        LEGACYAssertThrowsWithReason([subs addSubscriptionWithClassName:Person.className
                                                    subscriptionName:@"person_age"
                                                               where:@"age > 20"],
                                  @"A subscription named 'person_age' already exists. If you meant to update the existing subscription please use the `update` method.");
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_age"];
    XCTAssertNotNil(foundSubscription);

    XCTAssertEqualObjects(foundSubscription.name, @"person_age");
    XCTAssertEqualObjects(foundSubscription.queryString, @"age > 15");
    XCTAssertEqualObjects(foundSubscription.objectClassName, @"Person");
}

- (void)testAddDuplicateSubscriptionWithPredicate {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Person.className
                                 predicate:[NSPredicate predicateWithFormat:@"age > %d", 15]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);
}

- (void)testAddDuplicateSubscriptionWithDifferentName {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_1"
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_2"
                                 predicate:[NSPredicate predicateWithFormat:@"age > %d", 15]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 2UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_age_1"];
    XCTAssertNotNil(foundSubscription);

    LEGACYSyncSubscription *foundSubscription2 = [subs subscriptionWithName:@"person_age_2"];
    XCTAssertNotNil(foundSubscription2);

    XCTAssertNotEqualObjects(foundSubscription.name, foundSubscription2.name);
    XCTAssertEqualObjects(foundSubscription.queryString, foundSubscription2.queryString);
    XCTAssertEqualObjects(foundSubscription.objectClassName, foundSubscription2.objectClassName);
}

- (void)testOverrideNamedWithUnnamedSubscription {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_1"
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Person.className
                                 predicate:[NSPredicate predicateWithFormat:@"age > %d", 15]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 2UL);
}

- (void)testOverrideUnnamedWithNamedSubscription {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                                 predicate:[NSPredicate predicateWithFormat:@"age > %d", 15]];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_1"
                                     where:@"age > 15"];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 2UL);
}

- (void)testAddSubscriptionInDifferentWriteBlocks {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_1"
                                     where:@"age > 15"];
    }];

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_2"
                                 predicate:[NSPredicate predicateWithFormat:@"age > %d", 20]];
    }];

    XCTAssertEqual(realm.subscriptions.version, 2UL);
    XCTAssertEqual(realm.subscriptions.count, 2UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_age_1"];
    XCTAssertNotNil(foundSubscription);

    LEGACYSyncSubscription *foundSubscription2 = [subs subscriptionWithName:@"person_age_2"];
    XCTAssertNotNil(foundSubscription2);
}

- (void)testRemoveSubscriptionByName {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_1"
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_2"
                                 predicate:[NSPredicate predicateWithFormat:@"age > %d", 20]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 2UL);

    [subs update:^{
        [subs removeSubscriptionWithName:@"person_age_1"];
    }];

    XCTAssertEqual(subs.version, 2UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_age_1"];
    XCTAssertNil(foundSubscription);

    LEGACYSyncSubscription *foundSubscription2 = [subs subscriptionWithName:@"person_age_2"];
    XCTAssertNotNil(foundSubscription2);
}

- (void)testRemoveSubscriptionWithoutWriteThrow {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age_1"
                                     where:@"age > 15"];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);
    LEGACYAssertThrowsWithReason([subs removeSubscriptionWithName:@"person_age_1"], @"Can only add, remove, or update subscriptions within a write subscription block.");
}

- (void)testRemoveSubscriptionByQuery {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age"
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_firstname"
                                     where:@"firstName == %@", @"John"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_lastname"
                                 predicate:[NSPredicate predicateWithFormat:@"lastName == %@", @"Doe"]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 3UL);

    [subs update:^{
        [subs removeSubscriptionWithClassName:Person.className where:@"firstName == %@", @"John"];
        [subs removeSubscriptionWithClassName:Person.className predicate:[NSPredicate predicateWithFormat:@"lastName == %@", @"Doe"]];
    }];

    XCTAssertEqual(subs.version, 2UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_age"];
    XCTAssertNotNil(foundSubscription);

    LEGACYSyncSubscription *foundSubscription2 = [subs subscriptionWithName:@"person_firstname"];
    XCTAssertNil(foundSubscription2);

    LEGACYSyncSubscription *foundSubscription3 = [subs subscriptionWithName:@"person_lastname"];
    XCTAssertNil(foundSubscription3);
}

- (void)testRemoveSubscription {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age"
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_firstname"
                                     where:@"firstName == '%@'", @"John"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_lastname"
                                 predicate:[NSPredicate predicateWithFormat:@"lastName == %@", @"Doe"]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 3UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_age"];
    XCTAssertNotNil(foundSubscription);

    [subs update:^{
        [subs removeSubscription:foundSubscription];
    }];

    XCTAssertEqual(subs.version, 2UL);
    XCTAssertEqual(subs.count, 2UL);

    LEGACYSyncSubscription *foundSubscription2 = [subs subscriptionWithName:@"person_firstname"];
    XCTAssertNotNil(foundSubscription2);

    [subs update:^{
        [subs removeSubscription:foundSubscription2];
    }];

    XCTAssertEqual(subs.version, 3UL);
    XCTAssertEqual(subs.count, 1UL);
}

- (void)testRemoveAllSubscription {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age"
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_firstname"
                                     where:@"firstName == '%@'", @"John"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_lastname"
                                 predicate:[NSPredicate predicateWithFormat:@"lastName == %@", @"Doe"]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 3UL);

    [subs update:^{
        [subs removeAllSubscriptions];
    }];

    XCTAssertEqual(subs.version, 2UL);
    XCTAssertEqual(subs.count, 0UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_age_3"];
    XCTAssertNil(foundSubscription);
}

- (void)testRemoveAllSubscriptionForType {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age"
                                     where:@"age > 15"];
        [subs addSubscriptionWithClassName:Dog.className
                          subscriptionName:@"dog_name"
                                     where:@"name == '%@'", @"Tomas"];
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_lastname"
                                 predicate:[NSPredicate predicateWithFormat:@"lastName == %@", @"Doe"]];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 3UL);

    [subs update:^{
        [subs removeAllSubscriptionsWithClassName:Person.className];
    }];

    XCTAssertEqual(subs.version, 2UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"dog_name"];
    XCTAssertNotNil(foundSubscription);

    [subs update:^{
        [subs removeAllSubscriptionsWithClassName:Dog.className];
    }];

    XCTAssertEqual(subs.version, 3UL);
    XCTAssertEqual(subs.count, 0UL);
}

- (void)testUpdateSubscriptionQuery {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"person_age"
                                     where:@"age > 15"];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"person_age"];
    XCTAssertNotNil(foundSubscription);

    [subs update:^{
        [foundSubscription updateSubscriptionWhere:@"age > 20"];
    }];

    XCTAssertEqual(subs.version, 2UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription2 = [subs subscriptionWithName:@"person_age"];
    XCTAssertNotNil(foundSubscription2);
    XCTAssertEqualObjects(foundSubscription2.queryString, @"age > 20");
    XCTAssertEqualObjects(foundSubscription2.objectClassName, @"Person");
}

- (void)testUpdateSubscriptionQueryWithoutWriteThrow {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    [subs update:^{
        [subs addSubscriptionWithClassName:Person.className
                          subscriptionName:@"subscription_1"
                                     where:@"age > 15"];
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, 1UL);

    LEGACYSyncSubscription *foundSubscription = [subs subscriptionWithName:@"subscription_1"];
    XCTAssertNotNil(foundSubscription);

    LEGACYAssertThrowsWithReason([foundSubscription updateSubscriptionWithPredicate:[NSPredicate predicateWithFormat:@"name == 'Tomas'"]], @"Can only add, remove, or update subscriptions within a write subscription block.");
}

- (void)testSubscriptionSetIterate {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    double numberOfSubs = 100;
    [subs update:^{
        for (int i = 0; i < numberOfSubs; ++i) {
            [subs addSubscriptionWithClassName:Person.className
                              subscriptionName:[NSString stringWithFormat:@"person_age_%d", i]
                                         where:[NSString stringWithFormat:@"age > %d", i]];
        }
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, (unsigned long)numberOfSubs);

    __weak id objects[(unsigned long)pow(numberOfSubs, 2.0) + (unsigned long)numberOfSubs];
    NSInteger count = 0;
    for (LEGACYSyncSubscription *sub in subs) {
        XCTAssertNotNil(sub);
        objects[count++] = sub;
        for (LEGACYSyncSubscription *sub in subs) {
            objects[count++] = sub;
        }
    }
    XCTAssertEqual(count, pow(numberOfSubs, 2) + numberOfSubs);
}

- (void)testSubscriptionSetFirstAndLast {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    XCTAssertNil(subs.firstObject);
    XCTAssertNil(subs.lastObject);

    int numberOfSubs = 20;
    [subs update:^{
        for (int i = 1; i <= numberOfSubs; ++i) {
            [subs addSubscriptionWithClassName:Person.className
                              subscriptionName:[NSString stringWithFormat:@"person_age_%d", i]
                                         where:[NSString stringWithFormat:@"age > %d", i]];
        }
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, (unsigned long)numberOfSubs);

    LEGACYSyncSubscription *firstSubscription = subs.firstObject;
    XCTAssertEqualObjects(firstSubscription.name, @"person_age_1");
    XCTAssertEqualObjects(firstSubscription.queryString, @"age > 1");

    LEGACYSyncSubscription *lastSubscription = subs.lastObject;
    XCTAssertEqualObjects(lastSubscription.name, ([NSString stringWithFormat:@"person_age_%d", numberOfSubs]));
    XCTAssertEqualObjects(lastSubscription.queryString, ([NSString stringWithFormat:@"age > %d", numberOfSubs]));
}

- (void)testSubscriptionSetSubscript {
    LEGACYRealm *realm = [self openRealm];
    LEGACYSyncSubscriptionSet *subs = realm.subscriptions;

    XCTAssertEqual(subs.count, 0UL);

    int numberOfSubs = 20;
    [subs update:^{
        for (int i = 1; i <= numberOfSubs; ++i) {
            [subs addSubscriptionWithClassName:Person.className
                              subscriptionName:[NSString stringWithFormat:@"person_age_%d", i]
                                         where:[NSString stringWithFormat:@"age > %d", i]];
        }
    }];

    XCTAssertEqual(subs.version, 1UL);
    XCTAssertEqual(subs.count, (unsigned long)numberOfSubs);

    LEGACYSyncSubscription *firstSubscription = subs[0];
    XCTAssertEqualObjects(firstSubscription.name, @"person_age_1");
    XCTAssertEqualObjects(firstSubscription.queryString, @"age > 1");

    LEGACYSyncSubscription *lastSubscription = subs[numberOfSubs-1];
    XCTAssertEqualObjects(lastSubscription.name, ([NSString stringWithFormat:@"person_age_%d", numberOfSubs]));
    XCTAssertEqualObjects(lastSubscription.queryString, ([NSString stringWithFormat:@"age > %d", numberOfSubs]));

    int index = (numberOfSubs/2);
    LEGACYSyncSubscription *objectAtIndexSubscription = [subs objectAtIndex:index];
    XCTAssertEqualObjects(objectAtIndexSubscription.name, ([NSString stringWithFormat:@"person_age_%d", index+1]));
    XCTAssertEqualObjects(objectAtIndexSubscription.queryString, ([NSString stringWithFormat:@"age > %d", index+1]));
}
@end
