//
//  HTTPRequest+URLRequest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation

// MARK: - URLRequest Encoding helpers
/// Default implementations that turn an `HTTPRequest` into a `URLRequest`.
///
/// Conforming types may override specific pieces (for example,
/// `encodeURLRequest(baseURL:)` or `encodeHTTPBody()`) to customize behavior,
/// while continuing to rely on shared setup provided here.
public extension HTTPRequest {
    /// Encodes this request into a `URLRequest` using JSON encoding by default.
    ///
    /// Conforming types may override this method to provide alternate encoding strategies
    /// (e.g., `application/x-www-form-urlencoded`, multipart, or custom formats), or to apply
    /// additional per-request configuration.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed `URLRequest` ready for sending.
    /// - Throws: An error if encoding the request fails.
    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        let url = requestURL(baseURL: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.httpBody = try encodeHTTPBody()
        return urlRequest
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
    /// - Throws: Any error thrown by the encoder while encoding `httpBody`.
    func encodeHTTPBody() throws -> Data? {
        if RequestBody.self == Never.self {
            return nil
        } else if RequestBody.self == Never?.self {
            return nil
        }

        return try JSONEncoder().encode(httpBody)
    }
}

