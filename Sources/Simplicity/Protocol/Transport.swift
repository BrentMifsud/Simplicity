public import Foundation
public import HTTPTypes

/// An abstraction over the network layer used by ``URLSessionClient`` to execute HTTP requests.
///
/// The protocol operates at the `HTTPRequest`/`HTTPResponse` level (from Apple's `swift-http-types`),
/// keeping URLSession-specific concerns (like `URLRequest` conversion) inside concrete implementations.
///
/// By default, ``URLSessionTransport`` wraps a real `URLSession`. In tests, inject a custom
/// conformance (e.g. a mock struct) to avoid global mutable state and enable parallel test execution.
public protocol Transport: Sendable {
    /// Sends a data request and returns the response.
    /// - Parameters:
    ///   - request: The HTTP request to send.
    ///   - body: The request body data, or `nil` for bodyless requests.
    ///   - cachePolicy: The cache policy for this request.
    ///   - timeout: The timeout duration for this request.
    /// - Returns: A tuple of the response body data, HTTP response, and final URL.
    func data(
        for request: HTTPRequest,
        body: Data?,
        cachePolicy: CachePolicy,
        timeout: Duration
    ) async throws -> (Data, HTTPResponse, URL)

    /// Uploads data and returns the response.
    /// - Parameters:
    ///   - request: The HTTP request to send.
    ///   - bodyData: The data to upload.
    ///   - timeout: The timeout duration for this request.
    /// - Returns: A tuple of the response body data, HTTP response, and final URL.
    func upload(
        for request: HTTPRequest,
        from bodyData: Data,
        timeout: Duration
    ) async throws -> (Data, HTTPResponse, URL)
}
