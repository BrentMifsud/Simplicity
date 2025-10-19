public import Foundation

/// A concrete HTTP client that uses `URLSession` to send requests and receive responses,
/// with support for a configurable base URL and a chain of middlewares.
///
/// `URLSessionHTTPClient` conforms to `HTTPClient` and is suitable for most networking
/// scenarios on Apple platforms. It encodes an `HTTPRequest` into a `URLRequest`,
/// executes it using the provided `URLSession`, and produces an `HTTPResponse<Success, Failure>`
/// that defers decoding until you explicitly call `decodeSuccessBody()` or `decodeFailureBody()`.
///
/// Features:
/// - Base URL composition for relative endpoints
/// - Pluggable middleware chain for request/response interception
/// - Configurable cache policy and timeout per request
/// - Cooperative cancellation checks during request execution
/// - On-demand decoding for both success and failure payloads
///
/// Thread-safety:
/// - The type is `nonisolated` and can be used across concurrency domains. If you plan to
///   mutate `baseURL` or `middlewares` from multiple tasks, coordinate those writes. These
///   properties are intended to be changed sparingly (e.g., when switching environments or
///   installing auth middleware after obtaining a bearer token).
public nonisolated struct URLSessionHTTPClient: HTTPClient {
    let urlSession: URLSession
    public var baseURL: URL
    public var middlewares: [any Middleware]

    /// Initializes a new HTTPClient instance.
    /// - Parameters:
    ///   - urlSession: The URLSession to use. Defaults to `.shared`.
    ///   - baseURL: The base URL for HTTP requests.
    ///   - middlewares: Middlewares for intercepting and modifying requests/responses.
    public init(urlSession: URLSession = .shared, baseURL: URL, middlewares: [any Middleware]) {
        self.urlSession = urlSession
        self.baseURL = baseURL
        self.middlewares = middlewares
    }

    /// Sends a typed HTTP request using `URLSession`, applying middleware and client configuration.
    ///
    /// The request is encoded into a `URLRequest` using the request's `encodeURLRequest(baseURL:)`,
    /// then passed through the middleware chain for mutation. The response is returned as an
    /// `HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody>`, which supports
    /// on-demand decoding of success and failure bodies.
    ///
    /// - Parameters:
    ///   - request: The typed request to send.
    ///   - cachePolicy: Cache policy to apply to the URLRequest. Defaults to `.useProtocolCachePolicy`.
    ///   - timeout: Timeout for the request. Defaults to 30 seconds.
    /// - Returns: An `HTTPResponse` carrying status, headers, final URL, raw bytes, and decoders
    ///   for both success and failure bodies.
    /// - Throws: Any error thrown during request encoding, middleware processing, network transfer,
    ///   or response handling (including cancellation and URLSession errors).
    @concurrent
    public func send<Request: HTTPRequest>(
        request: Request,
        cachePolicy: CachePolicy = .useProtocolCachePolicy,
        timeout: Duration = .seconds(30)
    ) async throws -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody> {
        try Task.checkCancellation()

        var next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { [urlSession] middlewareRequest -> Middleware.Response in
            // Build a URLRequest from the original typed request, but apply middleware mutations
            var urlRequest = try request.encodeURLRequest(baseURL: middlewareRequest.baseURL)
            urlRequest.httpMethod = middlewareRequest.httpMethod.rawValue
            // Apply/override headers from middleware
            for (key, value) in middlewareRequest.headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
            // Apply/override body from middleware
            urlRequest.httpBody = middlewareRequest.httpBody

            // Apply client-provided cache policy and timeout
            urlRequest.cachePolicy = cachePolicy.urlRequestCachePolicy
            urlRequest.timeoutInterval = TimeInterval(timeout.components.seconds)

            try Task.checkCancellation()
            let (data, response) = try await urlSession.data(for: urlRequest)
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.unknown, userInfo: ["reason" : "Response was not an HTTP response"])
            }

            guard let statusCode = HTTPStatusCode(rawValue: httpResponse.statusCode) else {
                throw URLError(.badServerResponse, userInfo: ["reason": "Invalid HTTP status code: \(httpResponse.statusCode)"])
            }

            guard let url = httpResponse.url ?? urlRequest.url else {
                throw URLError(.unknown, userInfo: ["reason": "URL is missing from httpResponse or urlRequest"])
            }

            // Convert header fields from [AnyHashable: Any] to [String: String]
            let headers: [String: String] = httpResponse.allHeaderFields.reduce(into: [:]) { dict, pair in
                if let key = pair.key as? String,
                   let value = pair.value as? String {
                    dict[key] = value
                }
            }

            return (statusCode: statusCode, url: url, headers: headers, httpBody: data)
        }
        
        for middleware in middlewares.reversed() {
            let tmp = next
            next = { request in
                try Task.checkCancellation()
                return try await middleware.intercept(
                    request: request,
                    next: tmp
                )
            }
        }

        let requestBody: Data? = if Request.RequestBody.self == Never.self || Request.RequestBody.self == Never?.self {
            .none
        } else {
            try request.encodeHTTPBody()
        }

        try Task.checkCancellation()

        let initialMiddlewareRequest: Middleware.Request = (
            operationID: type(of: request).operationID,
            httpMethod: request.httpMethod,
            baseURL: baseURL,
            path: request.path,
            headers: request.headers,
            httpBody: requestBody
        )

        let response = try await next(initialMiddlewareRequest)

        try Task.checkCancellation()

        return makeResponse(
            statusCode: response.statusCode,
            url: response.url,
            headers: response.headers,
            httpBody: response.httpBody,
            for: request
        )
    }
}

private extension URLSessionHTTPClient {
    // MARK: - Response Builders

    // General case: both Success and Failure exist
    private func makeResponse<Request: HTTPRequest>(
        statusCode: HTTPStatusCode,
        url: URL,
        headers: [String: String],
        httpBody: Data,
        for request: Request
    ) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody> {
        HTTPResponse(
            statusCode: statusCode,
            url: url,
            headers: headers,
            httpBody: httpBody,
            successBodyDecoder: { data in
                try request.decodeSuccessResponseData(data)
            },
            failureBodyDecoder: { data in
                try request.decodeFailureResponseData(data)
            }
        )
    }

    // Specialized: Failure == Never (success-only)
    private func makeResponse<Request: HTTPRequest>(
        statusCode: HTTPStatusCode,
        url: URL,
        headers: [String: String],
        httpBody: Data,
        for request: Request
    ) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody>
    where Request.FailureResponseBody == Never {
        HTTPResponse(
            statusCode: statusCode,
            url: url,
            headers: headers,
            httpBody: httpBody,
            successBodyDecoder: { data in
                try request.decodeSuccessResponseData(data)
            }
        )
    }

    // Specialized: Success == Never (failure-only)
    private func makeResponse<Request: HTTPRequest>(
        statusCode: HTTPStatusCode,
        url: URL,
        headers: [String: String],
        httpBody: Data,
        for request: Request
    ) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody>
    where Request.SuccessResponseBody == Never {
        HTTPResponse(
            statusCode: statusCode,
            url: url,
            headers: headers,
            httpBody: httpBody,
            failureBodyDecoder: { data in
                try request.decodeFailureResponseData(data)
            }
        )
    }
}
