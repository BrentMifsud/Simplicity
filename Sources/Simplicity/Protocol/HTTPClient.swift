//
//  HTTPClient.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

import Foundation

public nonisolated protocol HTTPClient: Sendable {
    /// Sends an HTTP request using the middleware chain, returning the decoded response body.
    ///
    /// This method builds the middleware chain, constructs a `URLRequest`, and performs the network call. Each middleware may intercept, modify, or observe the request and response. The final response data is decoded into the expected response type.
    ///
    /// - Parameter request: The request conforming to `HTTPRequest` to send.
    /// - Returns: The decoded response body of type `Request.ResponseBody`.
    /// - Throws: Any error thrown by the request encoding, network transport, middleware, or response decoding.
    @concurrent
    func send<Request: HTTPRequest>(
        request: Request,
        cachePolicy: CachePolicy,
        timeout: Duration
    ) async throws -> Request.ResponseBody
}
