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

#import "LEGACYNetworkTransport_Private.hpp"

#import "LEGACYApp.h"
#import "LEGACYError.h"
#import "LEGACYRealmConfiguration.h"
#import "LEGACYSyncUtil_Private.hpp"
#import "LEGACYSyncManager_Private.hpp"
#import "LEGACYUtil.hpp"

#import <realm/object-store/sync/generic_network_transport.hpp>
#import <realm/util/scope_exit.hpp>

using namespace realm;

static_assert((int)LEGACYHTTPMethodGET        == (int)app::HttpMethod::get);
static_assert((int)LEGACYHTTPMethodPOST       == (int)app::HttpMethod::post);
static_assert((int)LEGACYHTTPMethodPUT        == (int)app::HttpMethod::put);
static_assert((int)LEGACYHTTPMethodPATCH      == (int)app::HttpMethod::patch);
static_assert((int)LEGACYHTTPMethodDELETE     == (int)app::HttpMethod::del);

#pragma mark LEGACYSessionDelegate

@interface LEGACYSessionDelegate <NSURLSessionDelegate> : NSObject
+ (instancetype)delegateWithCompletion:(LEGACYNetworkTransportCompletionBlock)completion;
@end

NSString * const LEGACYHTTPMethodToNSString[] = {
    [LEGACYHTTPMethodGET] = @"GET",
    [LEGACYHTTPMethodPOST] = @"POST",
    [LEGACYHTTPMethodPUT] = @"PUT",
    [LEGACYHTTPMethodPATCH] = @"PATCH",
    [LEGACYHTTPMethodDELETE] = @"DELETE"
};

@implementation LEGACYRequest
@end

@implementation LEGACYResponse
@end

@interface LEGACYEventSessionDelegate <NSURLSessionDelegate> : NSObject
+ (instancetype)delegateWithEventSubscriber:(id<LEGACYEventDelegate>)subscriber;
@end;

@implementation LEGACYNetworkTransport

- (void)sendRequestToServer:(LEGACYRequest *)request
                 completion:(LEGACYNetworkTransportCompletionBlock)completionBlock {
    // Create the request
    NSURL *requestURL = [[NSURL alloc] initWithString: request.url];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:requestURL];
    urlRequest.HTTPMethod = LEGACYHTTPMethodToNSString[request.method];
    if (![urlRequest.HTTPMethod isEqualToString:@"GET"]) {
        urlRequest.HTTPBody = [request.body dataUsingEncoding:NSUTF8StringEncoding];
    }
    urlRequest.timeoutInterval = request.timeout;

    for (NSString *key in request.headers) {
        [urlRequest addValue:request.headers[key] forHTTPHeaderField:key];
    }
    id delegate = [LEGACYSessionDelegate delegateWithCompletion:completionBlock];
    auto session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                                                 delegate:delegate delegateQueue:nil];

    // Add the request to a task and start it
    [[session dataTaskWithRequest:urlRequest] resume];
    // Tell the session to destroy itself once it's done with the request
    [session finishTasksAndInvalidate];
}

- (NSURLSession *)doStreamRequest:(nonnull LEGACYRequest *)request
                  eventSubscriber:(nonnull id<LEGACYEventDelegate>)subscriber {
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.timeoutIntervalForRequest = 30;
    sessionConfig.timeoutIntervalForResource = INT_MAX;
    sessionConfig.HTTPAdditionalHeaders = @{
        @"Content-Type": @"text/event-stream",
        @"Cache": @"no-cache",
        @"Accept": @"text/event-stream"
    };
    id delegate = [LEGACYEventSessionDelegate delegateWithEventSubscriber:subscriber];
    auto session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                 delegate:delegate
                                            delegateQueue:nil];
    NSURL *url = [[NSURL alloc] initWithString:request.url];
    [[session dataTaskWithURL:url] resume];
    return session;
}

LEGACYRequest *LEGACYRequestFromRequest(realm::app::Request const& request) {
    LEGACYRequest *rlmRequest = [LEGACYRequest new];
    NSMutableDictionary<NSString *, NSString*> *headersDict = [NSMutableDictionary new];
    for (auto &[key, value] : request.headers) {
        headersDict[@(key.c_str())] = @(value.c_str());
    }
    rlmRequest.headers = headersDict;
    rlmRequest.method = static_cast<LEGACYHTTPMethod>(request.method);
    rlmRequest.timeout = request.timeout_ms;
    rlmRequest.url = @(request.url.c_str());
    rlmRequest.body = @(request.body.c_str());
    return rlmRequest;
}

@end

#pragma mark LEGACYSessionDelegate

@implementation LEGACYSessionDelegate {
    NSData *_data;
    LEGACYNetworkTransportCompletionBlock _completionBlock;
}

+ (instancetype)delegateWithCompletion:(LEGACYNetworkTransportCompletionBlock)completion {
    LEGACYSessionDelegate *delegate = [LEGACYSessionDelegate new];
    delegate->_completionBlock = completion;
    return delegate;
}

- (void)URLSession:(__unused NSURLSession *)session
          dataTask:(__unused NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if (!_data) {
        _data = data;
        return;
    }
    if (![_data respondsToSelector:@selector(appendData:)]) {
        _data = [_data mutableCopy];
    }
    [(id)_data appendData:data];
}

- (void)URLSession:(__unused NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    LEGACYResponse *response = [LEGACYResponse new];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) task.response;
    response.headers = httpResponse.allHeaderFields;
    response.httpStatusCode = httpResponse.statusCode;

    if (error) {
        response.body = error.localizedDescription;
        response.customStatusCode = error.code;
        return _completionBlock(response);
    }

    response.body = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];

    _completionBlock(response);
}

@end

@implementation LEGACYEventSessionDelegate {
    id<LEGACYEventDelegate> _subscriber;
    bool _hasOpened;
}

+ (instancetype)delegateWithEventSubscriber:(id<LEGACYEventDelegate>)subscriber {
    LEGACYEventSessionDelegate *delegate = [LEGACYEventSessionDelegate new];
    delegate->_subscriber = subscriber;
    return delegate;
}

- (void)URLSession:(__unused NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if (!_hasOpened) {
        _hasOpened = true;
        [_subscriber didOpen];
    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)dataTask.response;
    if (httpResponse.statusCode == 200) {
        return [_subscriber didReceiveEvent:data];
    }

    NSString *errorStatus = [NSString stringWithFormat:@"URLSession HTTP error code: %ld",
                             (long)httpResponse.statusCode];
    NSError *error = [NSError errorWithDomain:LEGACYAppErrorDomain
                                         code:LEGACYAppErrorHttpRequestFailed
                                     userInfo:@{NSLocalizedDescriptionKey: errorStatus,
                                                LEGACYHTTPStatusCodeKey: @(httpResponse.statusCode),
                                                NSURLErrorFailingURLErrorKey: dataTask.currentRequest.URL}];
    return [_subscriber didCloseWithError:error];
}

- (void)URLSession:(__unused NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    LEGACYResponse *response = [LEGACYResponse new];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
    response.headers = httpResponse.allHeaderFields;
    response.httpStatusCode = httpResponse.statusCode;

    // -999 indicates that the session was cancelled.
    if (error && (error.code != -999)) {
        response.body = [error localizedDescription];
        return [_subscriber didCloseWithError:error];
    }
    if (error && (error.code == -999)) {
        return [_subscriber didCloseWithError:nil];
    }
    if (response.httpStatusCode == 200) {
        return;
    }

    NSString *errorStatus = [NSString stringWithFormat:@"URLSession HTTP error code: %ld",
                             (long)httpResponse.statusCode];
    NSError *wrappedError = [NSError errorWithDomain:LEGACYAppErrorDomain
                                                code:LEGACYAppErrorHttpRequestFailed
                                            userInfo:@{NSLocalizedDescriptionKey: errorStatus,
                                                LEGACYHTTPStatusCodeKey: @(httpResponse.statusCode),
                                                       NSURLErrorFailingURLErrorKey: task.currentRequest.URL,
                                                       NSUnderlyingErrorKey: error}];
    return [_subscriber didCloseWithError:wrappedError];
}

@end
