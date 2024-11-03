////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import "LEGACYThreadSafeReference_Private.hpp"
#import "LEGACYUtil.hpp"

@implementation LEGACYThreadSafeReference {
    realm::ThreadSafeReference _reference;
    id _metadata;
    Class _type;
}

- (instancetype)initWithThreadConfined:(id<LEGACYThreadConfined>)threadConfined {
    if (!(self = [super init])) {
        return nil;
    }

    REALM_ASSERT_DEBUG([threadConfined conformsToProtocol:@protocol(LEGACYThreadConfined)]);
    if (![threadConfined conformsToProtocol:@protocol(LEGACYThreadConfined_Private)]) {
        @throw LEGACYException(@"Illegal custom conformance to `LEGACYThreadConfined` by `%@`", threadConfined.class);
    } else if (threadConfined.invalidated) {
        @throw LEGACYException(@"Cannot construct reference to invalidated object");
    } else if (!threadConfined.realm) {
        @throw LEGACYException(@"Cannot construct reference to unmanaged object, "
                            "which can be passed across threads directly");
    }

    LEGACYTranslateError([&] {
        _reference = [(id<LEGACYThreadConfined_Private>)threadConfined makeThreadSafeReference];
        _metadata = ((id<LEGACYThreadConfined_Private>)threadConfined).objectiveCMetadata;
    });
    _type = threadConfined.class;

    return self;
}

+ (instancetype)referenceWithThreadConfined:(id<LEGACYThreadConfined>)threadConfined {
    return [[self alloc] initWithThreadConfined:threadConfined];
}

- (id<LEGACYThreadConfined>)resolveReferenceInRealm:(LEGACYRealm *)realm {
    if (!_reference) {
        @throw LEGACYException(@"Can only resolve a thread safe reference once.");
    }
    return LEGACYTranslateError([&] {
        return [_type objectWithThreadSafeReference:std::move(_reference) metadata:_metadata realm:realm];
    });
}

- (BOOL)isInvalidated {
    return !_reference;
}

@end
