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

#import "LEGACYMongoClient_Private.hpp"

#import "LEGACYMongoDatabase_Private.hpp"
#import "LEGACYMongoCollection_Private.h"
#import "LEGACYApp_Private.hpp"

#import <realm/object-store/sync/mongo_client.hpp>
#import <realm/object-store/sync/mongo_database.hpp>
#import <realm/util/optional.hpp>

@implementation LEGACYMongoClient

- (instancetype)initWithUser:(LEGACYUser *)user serviceName:(NSString *)serviceName {
    if (self = [super init]) {
        _user = user;
        _name = serviceName;
    }
    return self;
}

- (LEGACYMongoDatabase *)databaseWithName:(NSString *)name {
    return [[LEGACYMongoDatabase alloc] initWithUser:self.user
                                      serviceName:self.name
                                     databaseName:name];
}

@end

@implementation LEGACYMongoDatabase

- (instancetype)initWithUser:(LEGACYUser *)user
                 serviceName:(NSString *)serviceName
                databaseName:(NSString *)databaseName {
    if (self = [super init]) {
        _user = user;
        _serviceName = serviceName;
        _name = databaseName;
    }
    return self;
}

- (LEGACYMongoCollection *)collectionWithName:(NSString *)name {
    return [[LEGACYMongoCollection alloc] initWithUser:self.user
                                       serviceName:self.serviceName
                                      databaseName:self.name
                                    collectionName:name];
}

@end
