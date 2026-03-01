//
//  Client.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation
public import HTTPTypes

public protocol Client: Sendable, Actor {
    /// The root URL used to build absolute request URLs for this client.
    ///
    /// Use `baseURL` to define the scheme, host, and optional base path that all
    /// relative request paths will be resolved against. For example, if a request
    /// specifies `path = "/users/42"`, the final URL will be constructed by
    /// appending that path to `baseURL`.
    ///
    /// - Must be a fully-qualified URL (e.g., `https://api.example.com`), and may
    ///   include an optional base path (e.g., `https://api.example.com/v1`).
    /// - Typically should not include query items or fragments; per-request
    ///   parameters should be provided by the `Request`.
    /// - Trailing slashes are normalized by URL resolution rules (e.g.,
    ///   `https://api.example.com/` + `/users` results in `https://api.example.com/users`).
    /// - If a request supplies an absolute URL, it should take precedence over
    ///   `baseURL` (implementation-dependent).
    /// - Changing this value affects all subsequent requests sent by the client.
    ///
    /// Example:
    /// ```swift
    /// client.baseURL = URL(string: "https://api.example.com/v1")!
    /// // Request with path "/users/42" resolves to:
    /// // https://api.example.com/v1/users/42
    /// ```
    ///
    /// Thread-safety note: Conformers should document whether mutations to
    /// `baseURL` are thread-safe when the client is used concurrently.
    var baseURL: URL { get }

    /// An ordered collection of middleware that intercepts every request sent by this client.
    ///
    /// Use `middlewares` to compose cross-cutting behaviors—such as authentication, request/response
    /// logging, retry/backoff, metrics, caching adapters, or header injection—without coupling them
    /// to individual requests.
    ///
    /// Execution order:
    /// - Request phase: middlewares are invoked from first to last (index 0 → end).
    /// - Response phase: middlewares unwind in reverse order (last → first), allowing outer
    ///   middlewares to observe and wrap the results of inner ones.
    ///
    /// Behavior and error handling:
    /// - Each middleware may inspect and modify the outgoing request and the incoming response.
    /// - Errors thrown by any middleware short-circuit the pipeline and are propagated to the caller.
    /// - Middleware should respect Swift concurrency and Task cancellation.
    ///
    /// Mutability and scope:
    /// - Mutating this array affects all subsequent requests made by the client.
    /// - Thread-safety of mutations is implementation-defined; consult the conformer's documentation
    ///   before mutating `middlewares` while requests are in flight.
    /// - Conformers typically default this collection to empty, but may provide sensible defaults
    ///   (e.g., logging) depending on the implementation.
    ///
    /// Ordering tips:
    /// - Place authentication/credential middlewares early so later middlewares see final headers.
    /// - Place retries around the transport (i.e., later in the array) so they can retry failures.
    /// - Place logging/metrics as the outermost layers (earliest) to capture the full lifecycle.
    ///
    /// Example:
    /// ```swift
    /// // Order matters: auth → retry → logging
    /// client.middlewares = [AuthMiddleware(), RetryMiddleware(), LoggingMiddleware()]
    /// ```
    var middlewares: [any Middleware] { get }

    /// Sets the root `baseURL` used to resolve relative request paths for this client.
    ///
    /// - Parameter url: The new base URL to apply to future requests.
    func setBaseURL(_ url: URL)

    /// Replaces the client's middleware pipeline with a new ordered collection.
    ///
    /// - Parameter middlewares: The new ordered list of middlewares to apply to all requests.
    func setMiddlewares(_ middlewares: [any Middleware])

    /// Sends an HTTP request using the middleware chain, returning the decoded response body.
    ///
    /// This method builds the middleware chain, constructs an `HTTPRequest`, and performs the
    /// network call. Each middleware may intercept, modify, or observe the request and response.
    /// The final response data is decoded into the expected response type.
    ///
    /// - Parameters:
    ///   - request: The request conforming to `Request` to send.
    ///   - cachePolicy: Cache policy to apply to the request.
    ///   - timeout: A per-call timeout duration for the request.
    /// - Returns: A `Response` carrying status, headers, final URL, raw bytes, and decoders.
    /// - Throws: `ClientError` when request construction, middleware, transport, or decoding fails.
    @concurrent
    func send<R: Request>(
        _ request: R,
        cachePolicy: CachePolicy,
        timeout: Duration
    ) async throws(ClientError) -> Response<R.SuccessResponseBody, R.FailureResponseBody>

    /// Uploads data for the given request through the middleware chain and returns a typed response.
    ///
    /// - Parameters:
    ///   - request: A type conforming to `UploadRequest` that defines the HTTP method, path/URL,
    ///     headers, and response decoding strategy.
    ///   - timeout: A per-call timeout duration for the upload operation.
    /// - Returns: A `Response` containing the HTTP status, headers, and a decoded body.
    /// - Throws: `ClientError` when request construction, middleware, transport, or decoding fails.
    @concurrent
    func upload<R: UploadRequest>(
        _ request: R,
        timeout: Duration
    ) async throws(ClientError) -> Response<R.SuccessResponseBody, R.FailureResponseBody>

    /// Clears any network response caches managed by the client.
    func clearNetworkCache() async

    // MARK: - Cache Management

    /// Stores a response in the cache for the given request.
    ///
    /// Use this method to manually cache a response that you want to be returned by subsequent
    /// requests with `returnCacheDataElseLoad` or `returnCacheDataDontLoad` cache policies.
    ///
    /// - Parameters:
    ///   - responseBody: The response body to cache. Must be `Encodable` to serialize for storage.
    ///   - request: The request to use as the cache key.
    ///   - status: The HTTP status to associate with the cached response. Defaults to `.ok`.
    ///   - headerFields: Optional HTTP header fields to associate with the cached response.
    /// - Throws: `ClientError.encodingError` if the response body cannot be serialized to JSON.
    func setCachedResponse<R: Request>(
        _ responseBody: R.SuccessResponseBody,
        for request: R,
        status: HTTPResponse.Status,
        headerFields: HTTPFields
    ) async throws(ClientError) where R.SuccessResponseBody: Encodable

    /// Retrieves the cached response for the given request.
    ///
    /// - Parameter request: The request to look up in the cache.
    /// - Returns: A `Response` containing the cached data.
    /// - Throws: `ClientError.cacheMiss` if no cached response exists for the request.
    func cachedResponse<R: Request>(
        for request: R
    ) async throws(ClientError) -> Response<R.SuccessResponseBody, R.FailureResponseBody>

    /// Removes the cached response for the given request.
    ///
    /// - Parameter request: The request whose cached response should be removed.
    func removeCachedResponse<R: Request>(
        for request: R
    ) async
}

public extension Client {
    func upload<R: UploadRequest>(
        _ request: R,
        timeout: Duration = .seconds(30)
    ) async throws(ClientError) -> Response<R.SuccessResponseBody, R.FailureResponseBody> where R.RequestBody == Never {
        fatalError("Upload requests must have data to send.")
    }
}
