////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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

import RealmLegacy

/**
 :nodoc:
 **/
public extension ObjectiveCSupport {
    /// Convert a `SyncConfiguration` to a `LEGACYSyncConfiguration`.
    static func convert(object: SyncConfiguration) -> LEGACYSyncConfiguration {
        return object.config
    }

    /// Convert a `LEGACYSyncConfiguration` to a `SyncConfiguration`.
    static func convert(object: LEGACYSyncConfiguration) -> SyncConfiguration {
        return SyncConfiguration(config: object)
    }

    /// Convert a `Credentials` to a `LEGACYCredentials`
    static func convert(object: Credentials) -> LEGACYCredentials {
        switch object {
        case .facebook(let accessToken):
            return LEGACYCredentials(facebookToken: accessToken)
        case .google(let serverAuthCode):
            return LEGACYCredentials(googleAuthCode: serverAuthCode)
        case .googleId(let token):
            return LEGACYCredentials(googleIdToken: token)
        case .apple(let idToken):
            return LEGACYCredentials(appleToken: idToken)
        case .emailPassword(let email, let password):
            return LEGACYCredentials(email: email, password: password)
        case .jwt(let token):
            return LEGACYCredentials(jwt: token)
        case .function(let payload):
            return LEGACYCredentials(functionPayload: ObjectiveCSupport.convert(object: AnyBSON(payload)) as! [String: LEGACYBSON])
        case .userAPIKey(let APIKey):
            return LEGACYCredentials(userAPIKey: APIKey)
        case .serverAPIKey(let serverAPIKey):
            return LEGACYCredentials(serverAPIKey: serverAPIKey)
        case .anonymous:
            return LEGACYCredentials.anonymous()
        }
    }
}
