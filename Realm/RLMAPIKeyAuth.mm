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

#import "LEGACYAPIKeyAuth.h"
#import "LEGACYProviderClient_Private.hpp"

#import "LEGACYApp_Private.hpp"
#import "LEGACYUserAPIKey_Private.hpp"
#import "LEGACYObjectId_Private.hpp"

using namespace realm::app;

@implementation LEGACYAPIKeyAuth

- (App::UserAPIKeyProviderClient)client {
    return self.app._realmApp->provider_client<App::UserAPIKeyProviderClient>();
}

- (std::shared_ptr<realm::SyncUser>)currentUser {
    return self.app._realmApp->current_user();
}

static realm::util::UniqueFunction<void(App::UserAPIKey, std::optional<AppError>)>
wrapCompletion(LEGACYOptionalUserAPIKeyBlock completion) {
    return [completion](App::UserAPIKey userAPIKey, std::optional<AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        return completion([[LEGACYUserAPIKey alloc] initWithUserAPIKey:userAPIKey], nil);
    };
}

- (void)createAPIKeyWithName:(NSString *)name
                  completion:(LEGACYOptionalUserAPIKeyBlock)completion {
    self.client.create_api_key(name.UTF8String, self.currentUser, wrapCompletion(completion));
}

- (void)fetchAPIKey:(LEGACYObjectId *)objectId
         completion:(LEGACYOptionalUserAPIKeyBlock)completion {
    self.client.fetch_api_key(objectId.value, self.currentUser, wrapCompletion(completion));
}

- (void)fetchAPIKeysWithCompletion:(LEGACYUserAPIKeysBlock)completion {
    self.client.fetch_api_keys(self.currentUser,
                               ^(const std::vector<App::UserAPIKey>& userAPIKeys,
                                 std::optional<AppError> error) {
        if (error) {
            return completion(nil, makeError(*error));
        }
        
        NSMutableArray *apiKeys = [[NSMutableArray alloc] init];
        for (auto &userAPIKey : userAPIKeys) {
            [apiKeys addObject:[[LEGACYUserAPIKey alloc] initWithUserAPIKey:userAPIKey]];
        }
        
        return completion(apiKeys, nil);
    });
}

- (void)deleteAPIKey:(LEGACYObjectId *)objectId
          completion:(LEGACYAPIKeyAuthOptionalErrorBlock)completion {
    self.client.delete_api_key(objectId.value, self.currentUser, LEGACYWrapCompletion(completion));
}

- (void)enableAPIKey:(LEGACYObjectId *)objectId
          completion:(LEGACYAPIKeyAuthOptionalErrorBlock)completion {
    self.client.enable_api_key(objectId.value, self.currentUser, LEGACYWrapCompletion(completion));
}

- (void)disableAPIKey:(LEGACYObjectId *)objectId
           completion:(LEGACYAPIKeyAuthOptionalErrorBlock)completion {
    self.client.disable_api_key(objectId.value, self.currentUser, LEGACYWrapCompletion(completion));
}

@end
