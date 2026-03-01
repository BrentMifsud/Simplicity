//
//  MiddlewareRequest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2026-03-01.
//

public import Foundation
public import HTTPTypes

/// The request value passed through the middleware chain.
///
/// `MiddlewareRequest` wraps Apple's `HTTPRequest` (which carries the HTTP method, URL
/// components, and header fields) and adds Simplicity-specific metadata: the raw body bytes,
/// an operation identifier, the original base URL, and the cache policy.
///
/// Middleware authors interact with the embedded `httpRequest` directly for familiar, standard
/// HTTP manipulation, while the additional properties provide context about the Simplicity
/// request lifecycle.
///
/// Access patterns:
/// - Method: `request.httpRequest.method`
/// - Headers: `request.httpRequest.headerFields[.authorization]`
/// - Body: `request.body`
/// - Full URL: `request.url` (computed from `httpRequest` components)
public struct MiddlewareRequest: Sendable {
    /// The underlying Apple HTTP request carrying method, URL components, and header fields.
    public var httpRequest: HTTPRequest

    /// The raw request body bytes, or `nil` for bodyless requests (e.g., GET, DELETE).
    public var body: Data?

    /// A unique identifier for the operation or endpoint (e.g., `"getUser"`).
    public var operationID: String

    /// The client's base URL at the time the request was created.
    ///
    /// Preserved for middleware inspection (e.g., logging, metrics). The authoritative URL
    /// is derived from `httpRequest`'s components; modifying `baseURL` does **not** change
    /// the request URL.
    public var baseURL: URL

    /// The cache policy governing how this request interacts with cached responses.
    public var cachePolicy: CachePolicy

    @inlinable
    public init(
        httpRequest: HTTPRequest,
        body: Data?,
        operationID: String,
        baseURL: URL,
        cachePolicy: CachePolicy
    ) {
        self.httpRequest = httpRequest
        self.body = body
        self.operationID = operationID
        self.baseURL = baseURL
        self.cachePolicy = cachePolicy
    }

    /// The full request URL reconstructed from the HTTP request's scheme, authority, and path.
    @inlinable
    public var url: URL {
        var string = ""
        if let scheme = httpRequest.scheme {
            string += scheme + "://"
        }
        if let authority = httpRequest.authority {
            string += authority
        }
        if let path = httpRequest.path {
            string += path
        }
        // The URL must be valid since it was decomposed from a valid URL originally.
        return URL(string: string)!
    }
}
