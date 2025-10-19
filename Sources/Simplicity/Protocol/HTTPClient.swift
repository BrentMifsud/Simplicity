//
//  HTTPClient.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation

public nonisolated protocol HTTPClient: Sendable {
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
    ///   parameters should be provided by the `HTTPRequest`.
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
    var baseURL: URL { get set }

    /// An ordered collection of middleware that intercepts every request sent by this client.
    ///
    /// Use `middlewares` to compose cross‑cutting behaviors—such as authentication, request/response
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
    /// - Errors thrown by any middleware short‑circuit the pipeline and are propagated to the caller.
    /// - Middleware should respect Swift concurrency and Task cancellation.
    ///
    /// Mutability and scope:
    /// - Mutating this array affects all subsequent requests made by the client.
    /// - Thread‑safety of mutations is implementation‑defined; consult the conformer’s documentation
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
    var middlewares: [any Middleware] { get set }

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
    ) async throws -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody>
}
