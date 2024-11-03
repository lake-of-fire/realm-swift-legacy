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

#import "LEGACYValue.h"
#import "LEGACYUtil.hpp"

#pragma mark NSData

@implementation NSData (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    return LEGACYPropertyTypeData;
}

@end

#pragma mark NSDate

@implementation NSDate (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    return LEGACYPropertyTypeDate;
}

@end

#pragma mark NSNumber

@implementation NSNumber (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    if ([self objCType][0] == 'c' && (self.intValue == 0 || self.intValue == 1)) {
        return LEGACYPropertyTypeBool;
    }
    else if (numberIsInteger(self)) {
        return LEGACYPropertyTypeInt;
    }
    else if (*@encode(float) == [self objCType][0]) {
        return LEGACYPropertyTypeFloat;
    }
    else if (*@encode(double) == [self objCType][0]) {
        return LEGACYPropertyTypeDouble;
    }
    else {
        @throw LEGACYException(@"Unknown numeric type on type LEGACYValue.");
    }
}

@end

#pragma mark NSNull

@implementation NSNull (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    return LEGACYPropertyTypeAny;
}

@end

#pragma mark NSString

@implementation NSString (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    return LEGACYPropertyTypeString;
}

@end

#pragma mark NSUUID

@implementation NSUUID (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    return LEGACYPropertyTypeUUID;
}

@end

#pragma mark LEGACYDecimal128

@implementation LEGACYDecimal128 (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    return LEGACYPropertyTypeDecimal128;
}

@end

#pragma mark LEGACYObjectBase

@implementation LEGACYObjectBase (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    return LEGACYPropertyTypeObject;
}

@end

#pragma mark LEGACYObjectId

@implementation LEGACYObjectId (LEGACYValue)

- (LEGACYPropertyType)rlm_valueType {
    return LEGACYPropertyTypeObjectId;
}

@end
