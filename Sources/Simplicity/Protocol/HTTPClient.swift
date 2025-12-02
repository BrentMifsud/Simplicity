//
//  HTTPClient.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation

public protocol HTTPClient: Sendable, Actor {
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
    var baseURL: URL { get }

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
    var middlewares: [any Middleware] { get }

    /// Sets the root `baseURL` used to resolve relative request paths for this client.
    ///
    /// Use this method to change the scheme, host, and optional base path that all
    /// subsequent requests will be built against. Relative paths provided by `HTTPRequest`
    /// instances are resolved against this URL. If a request supplies an absolute URL,
    /// it should take precedence (implementation‑dependent).
    ///
    /// - Important: The provided URL must be fully qualified (e.g., `https://api.example.com`)
    ///   and may include a base path (e.g., `https://api.example.com/v1`). Avoid including
    ///   query items or fragments; per‑request parameters should be specified by each
    ///   `HTTPRequest`.
    ///
    /// - Parameters:
    ///   - url: The new base URL to apply to future requests. Trailing slashes are normalized
    ///     by standard URL resolution rules (e.g., `https://api.example.com/` + `/users` →
    ///     `https://api.example.com/users`).
    ///
    /// - Concurrency: Conformers should document whether calling this method while other
    ///   requests are in flight is thread‑safe. Since the protocol refines `Actor`, typical
    ///   implementations will serialize mutations, but consult the specific conformer’s
    ///   documentation for details.
    ///
    /// - Effects: Changing the base URL affects all subsequent requests sent by the client;
    ///   it does not retroactively modify requests that have already been constructed or sent.
    ///
    /// - Example:
    ///   ```swift
    ///   await client.setBaseURL(URL(string: "https://api.example.com/v1")!)
    ///   // A request with path "/users/42" will resolve to:
    ///   // https://api.example.com/v1/users/42
    ///   ```
    func setBaseURL(_ url: URL)

    /// Replaces the client’s middleware pipeline with a new ordered collection.
    ///
    /// Use this to configure cross‑cutting behaviors—such as authentication, logging,
    /// retries/backoff, metrics, caching adapters, header injection, and more—that
    /// should apply to every request sent by this client.
    ///
    /// Execution order:
    /// - Request phase: middlewares run from first to last (index 0 → end).
    /// - Response phase: middlewares unwind in reverse order (last → first), allowing
    ///   outer middlewares to observe and wrap the results of inner ones.
    ///
    /// Behavior and error handling:
    /// - Each middleware may inspect and modify the outgoing request and the incoming response.
    /// - Errors thrown by any middleware short‑circuit the pipeline and are propagated to the caller.
    /// - Middlewares should respect Swift concurrency and Task cancellation.
    ///
    /// Mutability and scope:
    /// - Calling this method replaces the entire middleware array; it affects all subsequent requests.
    /// - Thread‑safety of mutations is implementation‑defined; consult the conformer’s documentation
    ///   before changing middlewares while requests are in flight.
    /// - Conformers may provide sensible defaults (e.g., logging) when no middlewares are set.
    ///
    /// Ordering tips:
    /// - Place authentication/credential middlewares early so later middlewares see final headers.
    /// - Place retries around the transport (i.e., later in the array) so they can retry failures.
    /// - Place logging/metrics as the outermost layers (earliest) to capture the full lifecycle.
    ///
    /// - Parameter middlewares: The new ordered list of middlewares to apply to all requests.
    ///   The order controls execution as described above.
    func setMiddlewares(_ middlewares: [any Middleware])

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
    ) async throws(ClientError) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody>

    /// Uploads raw data for the given HTTP request through the middleware chain and returns a typed response.
    ///
    /// This method constructs the request using the provided `HTTPRequest`, applies all configured
    /// `middlewares` in order, and performs an HTTP upload of the supplied `data`. Middlewares can
    /// inspect and modify the request and response, perform authentication, logging, retries, and more.
    /// The final response is decoded into the request’s declared success or failure body types.
    ///
    /// - Parameters:
    ///   - request: A type conforming to `HTTPRequest` that defines the HTTP method, path/URL,
    ///     headers, and response decoding strategy. Its associated `SuccessResponseBody` and
    ///     `FailureResponseBody` determine how the response is decoded.
    ///   - data: The raw payload to upload as the HTTP request body (e.g., JSON, binary, file bytes).
    ///     Implementations should set appropriate `Content-Type` headers either from the request or
    ///     inferred by middleware.
    ///   - timeout: A per‑call timeout duration for the upload operation. This overrides or augments
    ///     any default timeout configured by the client or underlying transport.
    ///
    /// - Returns: An `HTTPResponse` containing the HTTP status, headers, and a decoded body. On
    ///   success (per the request’s definition), the body is of type `Request.SuccessResponseBody`.
    ///   On server‑indicated failure, the body is of type `Request.FailureResponseBody`.
    ///
    /// - Throws: `ClientError` when request construction, middleware processing, transport, or decoding
    ///   fails. Cancellation errors may be thrown if the task is canceled. Errors thrown by any
    ///   middleware short‑circuit the pipeline and are propagated.
    ///
    /// - Concurrency: Marked `@concurrent` and `async`. Safe to call from concurrent contexts. Respect
    ///   task cancellation and the provided `timeout`.
    ///
    /// - Notes:
    ///   - Middlewares execute from first to last on the request path and unwind in reverse on response.
    ///   - Implementations should honor `baseURL` for relative paths and allow absolute URLs on the
    ///     request to take precedence.
    ///   - If the request already specifies a body in its encoding, this method’s `data` parameter
    ///     should be used as the source of truth; conformers should document precedence if both exist.
    ///
    /// - Example:
    ///   ```swift
    ///   let request = UploadAvatarRequest(userID: "42")
    ///   let imageData = try Data(contentsOf: avatarURL)
    ///   let response = try await client.upload(request: request,
    ///                                          data: imageData,
    ///                                          timeout: .seconds(30))
    ///   switch response.result {
    ///   case .success(let body):
    ///       // Handle decoded success body
    ///   case .failure(let errorBody):
    ///       // Handle decoded server error body
    ///   }
    ///   ```
    @concurrent
    func upload<Request: HTTPUploadRequest>(
        request: Request,
        timeout: Duration
    ) async throws(ClientError) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody>

    /// Clears any network response caches managed by the client.
    ///
    /// Use this method to invalidate and remove cached HTTP responses that the client (or its
    /// underlying transport) stores for reuse. This is typically backed by `URLCache` on Apple
    /// platforms, but concrete conformers may implement custom cache stores.
    ///
    /// Behavior:
    /// - Asynchronously removes both in‑memory and on‑disk cached responses owned by the client.
    /// - Does not throw; completion indicates best‑effort cache invalidation has finished.
    /// - In‑flight requests are not canceled. Their results may still be cached after completion,
    ///   depending on cache headers and the implementation.
    /// - Only affects caches that this client controls. It should not clear global or shared caches
    ///   that the client does not own.
    ///
    /// Concurrency and thread safety:
    /// - Safe to call from any context. Implementations should coordinate internal state so that
    ///   concurrent calls do not race or corrupt cache data.
    /// - May be awaited to ensure that subsequent requests will not read from previously cached
    ///   entries.
    ///
    /// Scope and middleware:
    /// - This clears stored response data, not credentials, cookies, keychain items, or persistent
    ///   authentication state (unless a specific middleware documents otherwise).
    /// - Middlewares that implement their own caches should respect this call by clearing their
    ///   stored entries, or document if they require separate invalidation.
    ///
    /// When to use:
    /// - After a user logs out or switches accounts.
    /// - When debugging caching behavior or ensuring fresh data after server‑side changes.
    /// - Prior to running deterministic tests that must not read stale responses.
    ///
    /// Notes:
    /// - Actual caching behavior depends on server cache headers, the `CachePolicy` used in `send`,
    ///   and the implementation’s storage strategy.
    /// - Implementations that do not maintain a cache may implement this as a no‑op.
    ///
    /// Example:
    /// ```swift
    /// await client.clearNetworkCache()
    /// // Subsequent requests will fetch fresh responses per cache policy.
    /// ```
    func clearNetworkCache() async

    // MARK: - Cache Management

    /// Stores a response in the cache for the given request.
    ///
    /// Use this method to manually cache a response that you want to be returned by subsequent
    /// requests with `returnCacheDataElseLoad` or `returnCacheDataDontLoad` cache policies.
    /// This is useful for:
    /// - Pre-populating the cache with known data
    /// - Updating cached data after a mutation (e.g., after subscribing, update the cached subscriptions list)
    /// - Working around server-side caching issues
    ///
    /// The cache key is derived from the request's URL (baseURL + path + queryItems). Two requests
    /// with identical URLs will share the same cache entry.
    ///
    /// - Parameters:
    ///   - responseBody: The response body to cache. Must be `Encodable` to serialize for storage.
    ///   - request: The request to use as the cache key. The URL is derived from `baseURL`, `path`, and `queryItems`.
    ///   - statusCode: The HTTP status code to associate with the cached response. Defaults to `.ok`.
    ///   - headers: Optional HTTP headers to associate with the cached response. Defaults to JSON content type.
    ///
    /// - Throws: `ClientError.encodingError` if the response body cannot be serialized to JSON.
    ///
    /// - Note: This method uses the same `URLCache` that backs `URLSession`, so cached responses
    ///   will be returned by `send(request:cachePolicy:timeout:)` when using appropriate cache policies.
    ///
    /// - Example:
    ///   ```swift
    ///   // After a mutation, update the cached list
    ///   let updatedSubscriptions = try await client.subscribe(to: subscriptionID)
    ///   try await client.setCachedResponse(
    ///       updatedSubscriptions,
    ///       for: CustomerSubscriptionsRequest(active: true, withMerchants: true)
    ///   )
    ///   ```
    func setCachedResponse<Request: HTTPRequest>(
        _ responseBody: Request.SuccessResponseBody,
        for request: Request,
        statusCode: HTTPStatusCode,
        headers: [String: String]
    ) async throws(ClientError) where Request.SuccessResponseBody: Encodable

    /// Retrieves the cached response for the given request.
    ///
    /// Use this method to check if a cached response exists and retrieve it without making
    /// a network request. This is useful for:
    /// - Checking cache state before deciding whether to fetch
    /// - Retrieving cached data for offline display
    /// - Debugging cache behavior
    ///
    /// - Parameter request: The request to look up in the cache.
    ///
    /// - Returns: An `HTTPResponse` containing the cached data.
    ///
    /// - Throws: `ClientError.cacheMiss` if no cached response exists for the request.
    ///
    /// - Note: This does not validate cache freshness or respect cache headers. It returns
    ///   whatever is stored, if anything.
    ///
    /// - Example:
    ///   ```swift
    ///   do {
    ///       let cached = try await client.cachedResponse(for: CustomerSubscriptionsRequest(...))
    ///       let subscriptions = try cached.decodeSuccessBody()
    ///       // Use cached data
    ///   } catch ClientError.cacheMiss {
    ///       // No cached data available
    ///   }
    ///   ```
    func cachedResponse<Request: HTTPRequest>(
        for request: Request
    ) async throws(ClientError) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody>

    /// Removes the cached response for the given request.
    ///
    /// Use this method to invalidate a specific cache entry. This is useful for:
    /// - Forcing a fresh fetch on the next request
    /// - Clearing stale data after a mutation that affects the cached resource
    /// - Selective cache invalidation without clearing the entire cache
    ///
    /// - Parameter request: The request whose cached response should be removed.
    ///
    /// - Note: If no cached response exists for the request, this method does nothing.
    ///
    /// - Example:
    ///   ```swift
    ///   // After unsubscribing, invalidate the cached subscriptions list
    ///   await client.removeCachedResponse(for: CustomerSubscriptionsRequest(...))
    ///   ```
    func removeCachedResponse<Request: HTTPRequest>(
        for request: Request
    ) async
}

public extension HTTPClient {
    func upload<Request: HTTPUploadRequest>(
        request: Request,
        timeout: Duration = .seconds(30)
    ) async throws(ClientError) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody> where Request.RequestBody == Never {
        fatalError("Upload requests must have data to send.")
    }
}
