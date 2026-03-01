//
//  MiddlewareResponse.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2026-03-01.
//

public import Foundation
public import HTTPTypes

/// The response value returned through the middleware chain.
///
/// `MiddlewareResponse` wraps Apple's `HTTPResponse` (which carries the status and header
/// fields) and adds the final URL and raw response body. Middleware can inspect and transform
/// these values before they are returned to the caller.
///
/// Access patterns:
/// - Status: `response.httpResponse.status`
/// - Headers: `response.httpResponse.headerFields`
/// - Body: `response.body`
/// - URL: `response.url`
public struct MiddlewareResponse: Sendable {
    /// The underlying Apple HTTP response carrying status and header fields.
    public var httpResponse: HTTPResponse

    /// The final URL of the response, which may differ from the request URL after redirects.
    public var url: URL

    /// The raw response body bytes.
    public var body: Data

    public init(httpResponse: HTTPResponse, url: URL, body: Data) {
        self.httpResponse = httpResponse
        self.url = url
        self.body = body
    }
}
