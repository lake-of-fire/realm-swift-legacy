////////////////////////////////////////////////////////////////////////////
//
// Copyright 2022 Realm Inc.
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

#import "LEGACYClassInfo.hpp"
#import "LEGACYSectionedResults.h"

#import <realm/object-store/results.hpp>
#import <realm/object-store/sectioned_results.hpp>

@protocol LEGACYValue;

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

LEGACY_HIDDEN_BEGIN

LEGACY_DIRECT_MEMBERS
@interface LEGACYSectionedResultsChange ()
- (instancetype)initWithChanges:(realm::SectionedResultsChangeSet)indices;
@end

LEGACY_DIRECT_MEMBERS
@interface LEGACYSectionedResultsEnumerator : NSObject

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len;

- (instancetype)initWithSectionedResults:(LEGACYSectionedResults *)sectionedResults;
- (instancetype)initWithResultsSection:(LEGACYSection *)resultsSection;

@end

@interface LEGACYSectionedResults ()

- (instancetype)initWithResults:(LEGACYResults *)results
                       keyBlock:(LEGACYSectionedResultsKeyBlock)keyBlock;

- (LEGACYSectionedResultsEnumerator *)fastEnumerator;
- (LEGACYClassInfo *)objectInfo;
- (LEGACYSectionedResults *)snapshot;

NSUInteger LEGACYFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            LEGACYSectionedResults *collection);

@end

@interface LEGACYSection ()

- (instancetype)initWithResultsSection:(realm::ResultsSection&&)resultsSection
                                parent:(LEGACYSectionedResults *)parent;

- (LEGACYSectionedResultsEnumerator *)fastEnumerator;
- (LEGACYClassInfo *)objectInfo;

NSUInteger LEGACYFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            LEGACYSection *collection);

@end

LEGACY_HIDDEN_END

LEGACY_HEADER_AUDIT_END(nullability, sendability)
