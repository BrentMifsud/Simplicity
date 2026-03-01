//
//  Request+HTTPRequest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation
public import HTTPTypes
import HTTPTypesFoundation

// MARK: - HTTPRequest Encoding helpers
/// Default implementations that turn a `Request` into an `HTTPRequest` (Apple's type).
///
/// Conforming types may override specific pieces (for example,
/// `makeHTTPRequest(baseURL:)` or `encodeBody()`) to customize behavior,
/// while continuing to rely on shared setup provided here.
public extension Request {
    /// Builds an `HTTPRequest` from this request's properties and the given base URL.
    ///
    /// The default implementation constructs an `HTTPRequest` using the `method`, resolved URL
    /// (from `baseURL` + `path` + `queryItems`), and `headerFields`.
    ///
    /// Conforming types may override this method to provide alternate URL construction or
    /// additional per-request configuration.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed `HTTPRequest` ready for sending.
    func makeHTTPRequest(baseURL: URL) -> HTTPRequest {
        HTTPRequest(method: method, url: requestURL(baseURL: baseURL), headerFields: headerFields)
    }

    /// Encodes the request body to `Data` using `JSONEncoder` by default.
    ///
    /// If `RequestBody` is `Never` or `Never?`, this method returns `nil`, indicating that
    /// the request has no body (e.g., for GET or DELETE requests).
    ///
    /// Conforming types may override this to provide an alternate encoding strategy, such as
    /// form encoding or multipart bodies, or to adjust the encoder configuration.
    ///
    /// - Returns: The encoded body data, or `nil` if no body is present.
    /// - Throws: Any error thrown by the encoder while encoding `body`.
    func encodeBody() throws -> Data? {
        if RequestBody.self == Never.self {
            return nil
        } else if RequestBody.self == Never?.self {
            return nil
        }

        return try JSONEncoder().encode(body)
    }
}
