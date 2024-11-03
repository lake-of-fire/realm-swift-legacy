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

#import <Realm/LEGACYConstants.h>
#import <Realm/LEGACYDecimal128.h>
#import <Realm/LEGACYObject.h>
#import <Realm/LEGACYObjectBase.h>
#import <Realm/LEGACYObjectId.h>
#import <Realm/LEGACYProperty.h>

#pragma mark LEGACYValue

/**
 LEGACYValue is a property type which represents a polymorphic Realm value. This is similar to the usage of
 `AnyObject` / `Any` in Swift.
```
 // A property on `MyObject`
 @property (nonatomic) id<LEGACYValue> myAnyValue;

 // A property on `AnotherObject`
 @property (nonatomic) id<LEGACYValue> myAnyValue;

 MyObject *myObject = [MyObject createInRealm:realm withValue:@[]];
 myObject.myAnyValue = @1234; // underlying type is NSNumber.
 myObject.myAnyValue = @"hello"; // underlying type is NSString.
 AnotherObject *anotherObject = [AnotherObject createInRealm:realm withValue:@[]];
 myObject.myAnyValue = anotherObject; // underlying type is LEGACYObject.
```
 The following types conform to LEGACYValue:

 `NSData`
 `NSDate`
 `NSNull`
 `NSNumber`
 `NSUUID`
 `NSString`
 `LEGACYObject
 `LEGACYObjectId`
 `LEGACYDecimal128`
 */
@protocol LEGACYValue

/// Describes the type of property stored.
@property (readonly) LEGACYPropertyType rlm_valueType;

@end

/// :nodoc:
@interface NSNull (LEGACYValue)<LEGACYValue>
@end

/// :nodoc:
@interface NSNumber (LEGACYValue)<LEGACYValue>
@end

/// :nodoc:
@interface NSString (LEGACYValue)<LEGACYValue>
@end

/// :nodoc:
@interface NSData (LEGACYValue)<LEGACYValue>
@end

/// :nodoc:
@interface NSDate (LEGACYValue)<LEGACYValue>
@end

/// :nodoc:
@interface NSUUID (LEGACYValue)<LEGACYValue>
@end

/// :nodoc:
@interface LEGACYDecimal128 (LEGACYValue)<LEGACYValue>
@end

/// :nodoc:
@interface LEGACYObjectBase (LEGACYValue)<LEGACYValue>
@end

/// :nodoc:
@interface LEGACYObjectId (LEGACYValue)<LEGACYValue>
@end
