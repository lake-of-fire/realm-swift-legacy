////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
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

#import <Foundation/Foundation.h>

#import <Realm/LEGACYArray.h>
#import <Realm/LEGACYAsyncTask.h>
#import <Realm/LEGACYDecimal128.h>
#import <Realm/LEGACYDictionary.h>
#import <Realm/LEGACYEmbeddedObject.h>
#import <Realm/LEGACYError.h>
#import <Realm/LEGACYGeospatial.h>
#import <Realm/LEGACYLogger.h>
#import <Realm/LEGACYMigration.h>
#import <Realm/LEGACYObject.h>
#import <Realm/LEGACYObjectId.h>
#import <Realm/LEGACYObjectSchema.h>
#import <Realm/LEGACYProperty.h>
#import <Realm/LEGACYRealm.h>
#import <Realm/LEGACYRealmConfiguration.h>
#import <Realm/LEGACYResults.h>
#import <Realm/LEGACYSchema.h>
#import <Realm/LEGACYSectionedResults.h>
#import <Realm/LEGACYSet.h>
#import <Realm/LEGACYValue.h>

#import <Realm/NSError+LEGACYSync.h>
#import <Realm/LEGACYAPIKeyAuth.h>
#import <Realm/LEGACYApp.h>
#import <Realm/LEGACYAsymmetricObject.h>
#import <Realm/LEGACYBSON.h>
#import <Realm/LEGACYCredentials.h>
#import <Realm/LEGACYEmailPasswordAuth.h>
#import <Realm/LEGACYFindOneAndModifyOptions.h>
#import <Realm/LEGACYFindOptions.h>
#import <Realm/LEGACYMongoClient.h>
#import <Realm/LEGACYMongoCollection.h>
#import <Realm/LEGACYMongoDatabase.h>
#import <Realm/LEGACYNetworkTransport.h>
#import <Realm/LEGACYProviderClient.h>
#import <Realm/LEGACYPushClient.h>
#import <Realm/LEGACYRealm+Sync.h>
#import <Realm/LEGACYSyncConfiguration.h>
#import <Realm/LEGACYSyncManager.h>
#import <Realm/LEGACYSyncSession.h>
#import <Realm/LEGACYSyncSubscription.h>
#import <Realm/LEGACYUpdateResult.h>
#import <Realm/LEGACYUser.h>
#import <Realm/LEGACYUserAPIKey.h>
