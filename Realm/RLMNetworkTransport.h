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

LEGACY_HEADER_AUDIT_BEGIN(nullability, sendability)

/// Allowed HTTP methods to be used with `LEGACYNetworkTransport`.
typedef LEGACY_CLOSED_ENUM(int32_t, LEGACYHTTPMethod) {
    /// GET is used to request data from a specified resource.
    LEGACYHTTPMethodGET    = 0,
    /// POST is used to send data to a server to create/update a resource.
    LEGACYHTTPMethodPOST   = 1,
    /// PATCH is used to send data to a server to update a resource.
    LEGACYHTTPMethodPATCH  = 2,
    /// PUT is used to send data to a server to create/update a resource.
    LEGACYHTTPMethodPUT    = 3,
    /// The DELETE method deletes the specified resource.
    LEGACYHTTPMethodDELETE = 4
};

/// An HTTP request that can be made to an arbitrary server.
@interface LEGACYRequest : NSObject

/// The HTTP method of this request.
@property (nonatomic, assign) LEGACYHTTPMethod method;

/// The URL to which this request will be made.
@property (nonatomic, strong) NSString *url;

/// The number of milliseconds that the underlying transport should spend on an
/// HTTP round trip before failing with an error.
@property (nonatomic, assign) NSTimeInterval timeout;

/// The HTTP headers of this request.
@property (nonatomic, strong) NSDictionary<NSString *, NSString *>* headers;

/// The body of the request.
@property (nonatomic, strong) NSString* body;

@end

/// The contents of an HTTP response.
@interface LEGACYResponse : NSObject

/// The status code of the HTTP response.
@property (nonatomic, assign) NSInteger httpStatusCode;

/// A custom status code provided by the SDK.
@property (nonatomic, assign) NSInteger customStatusCode;

/// The headers of the HTTP response.
@property (nonatomic, strong) NSDictionary<NSString *, NSString *>* headers;

/// The body of the HTTP response.
@property (nonatomic, strong) NSString *body;

@end

/// Delegate which is used for subscribing to changes.
@protocol LEGACYEventDelegate <NSObject>
/// Invoked when a change event has been received.
/// @param event The change event encoded as NSData
- (void)didReceiveEvent:(NSData *)event;
/// A error has occurred while subscribing to changes.
/// @param error The error that has occurred.
- (void)didReceiveError:(NSError *)error;
/// The stream was opened.
- (void)didOpen;
/// The stream has been closed.
/// @param error The error that has occurred.
- (void)didCloseWithError:(NSError *_Nullable)error;
@end

/// A block for receiving an `LEGACYResponse` from the `LEGACYNetworkTransport`.
LEGACY_SWIFT_SENDABLE // invoked on a backgroun thread
typedef void(^LEGACYNetworkTransportCompletionBlock)(LEGACYResponse *);

/// Transporting protocol for foreign interfaces. Allows for custom
/// request/response handling.
LEGACY_SWIFT_SENDABLE // used from multiple threads so must be internally thread-safe
@protocol LEGACYNetworkTransport <NSObject>

/**
 Sends a request to a given endpoint.

 @param request The request to send.
 @param completionBlock A callback invoked on completion of the request.
*/
- (void)sendRequestToServer:(LEGACYRequest *)request
                 completion:(LEGACYNetworkTransportCompletionBlock)completionBlock;

/// Starts an event stream request.
/// @param request The LEGACYRequest to start.
/// @param subscriber The LEGACYEventDelegate which will subscribe to changes from the server.
- (NSURLSession *)doStreamRequest:(LEGACYRequest *)request
                  eventSubscriber:(id<LEGACYEventDelegate>)subscriber;

@end

/// Transporting protocol for foreign interfaces. Allows for custom
/// request/response handling.
LEGACY_SWIFT_SENDABLE // is internally thread-safe
@interface LEGACYNetworkTransport : NSObject<LEGACYNetworkTransport>

/**
 Sends a request to a given endpoint.

 @param request The request to send.
 @param completionBlock A callback invoked on completion of the request.
*/
- (void)sendRequestToServer:(LEGACYRequest *) request
                 completion:(LEGACYNetworkTransportCompletionBlock)completionBlock;

@end

LEGACY_HEADER_AUDIT_END(nullability, sendability)
