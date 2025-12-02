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
public actor URLSessionHTTPClient: HTTPClient {
    let urlSession: URLSession
    public private(set) var baseURL: URL
    public private(set) var middlewares: [any Middleware]

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

    public func setBaseURL(_ url: URL) {
        baseURL = url
    }

    public func setMiddlewares(_ middlewares: [any Middleware]) {
        self.middlewares = middlewares
    }

    /// Sends a typed HTTP request using `URLSession`, applying middleware and client configuration.
    ///
    /// The request is encoded into a `URLRequest` using the request's `createURLRequest(baseURL:)`,
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
    ) async throws(ClientError) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody> {
        // If the task was cancelled immediately, exit early.
        if Task.isCancelled { throw ClientError.cancelled }

        // create URLRequest task to be executed
        var next = executeURLRequest(for: request, cachePolicy: cachePolicy, timeout: timeout)

        for middleware in await middlewares.reversed() {
            let tmp = next
            next = { middlewareRequest in
                do {
                    if Task.isCancelled { throw ClientError.cancelled }
                    return try await middleware.intercept(
                        request: middlewareRequest,
                        next: tmp
                    )
                } catch let error as ClientError {
                    throw error
                } catch {
                    throw ClientError.middleware(middleware: middleware, underlyingError: error)
                }
            }
        }

        let requestBody: Data?
        if Request.RequestBody.self == Never.self || Request.RequestBody.self == Never?.self {
            requestBody = nil
        } else {
            do {
                requestBody = try request.encodeHTTPBody()
            } catch {
                throw ClientError.encodingError(type: "\(Request.RequestBody.self)", underlyingError: error)
            }
        }

        let initialMiddlewareRequest: Middleware.Request = (
            operationID: type(of: request).operationID,
            httpMethod: request.httpMethod,
            baseURL: await baseURL,
            path: request.path,
            queryItems: request.queryItems,
            headers: request.headers,
            httpBody: requestBody
        )

        do {
            if Task.isCancelled { throw ClientError.cancelled }
            let response = try await next(initialMiddlewareRequest)
            return makeResponse(
                statusCode: response.statusCode,
                url: response.url,
                headers: response.headers,
                httpBody: response.httpBody,
                for: request
            )
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError.unknown(client: self, underlyingError: error)
        }
    }

    public func upload<Request: HTTPUploadRequest>(
        request: Request,
        timeout: Duration = .seconds(30)
    ) async throws(ClientError) -> HTTPResponse<Request.SuccessResponseBody, Request.FailureResponseBody> {
        // If the task was cancelled immediately, exit early.
        if Task.isCancelled { throw ClientError.cancelled }

        // create URLRequest task to be executed
        var next = executeUploadRequest(for: request, timeout: timeout)

        for middleware in middlewares.reversed() {
            let tmp = next
            next = { middlewareRequest in
                do {
                    if Task.isCancelled { throw ClientError.cancelled }
                    return try await middleware.intercept(
                        request: middlewareRequest,
                        next: tmp
                    )
                } catch let error as ClientError {
                    throw error
                } catch {
                    throw ClientError.middleware(middleware: middleware, underlyingError: error)
                }
            }
        }

        let uploadData: Data

        do {
            uploadData = try request.encodeUploadData()
        } catch {
            throw ClientError.encodingError(type: "\(Request.self)", underlyingError: error)
        }

        let initialMiddlewareRequest: Middleware.Request = (
            operationID: type(of: request).operationID,
            httpMethod: request.httpMethod,
            baseURL: baseURL,
            path: request.path,
            queryItems: request.queryItems,
            headers: request.headers,
            httpBody: uploadData
        )

        do {
            if Task.isCancelled { throw ClientError.cancelled }
            let response = try await next(initialMiddlewareRequest)
            return makeResponse(
                statusCode: response.statusCode,
                url: response.url,
                headers: response.headers,
                httpBody: response.httpBody,
                for: request
            )
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError.unknown(client: self, underlyingError: error)
        }
    }

    nonisolated private func executeURLRequest<Request: HTTPRequest>(
        for request: Request,
        cachePolicy: CachePolicy,
        timeout: Duration
    ) -> @Sendable (Middleware.Request) async throws -> Middleware.Response {
        { [urlSession] middlewareRequest async throws(ClientError) -> Middleware.Response in
            if Task.isCancelled { throw .cancelled }
            var urlRequest = request.createURLRequest(baseURL: middlewareRequest.baseURL)
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

            do {
                try Task.checkCancellation()
                let (data, response) = try await urlSession.data(for: urlRequest)
                try Task.checkCancellation()

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ClientError.invalidResponse("Response was not an HTTP response")
                }

                guard let statusCode = HTTPStatusCode(rawValue: httpResponse.statusCode) else {
                    throw ClientError.invalidResponse("Invalid HTTP status code: \(httpResponse.statusCode)")
                }

                guard let url = httpResponse.url ?? urlRequest.url else {
                    throw ClientError.invalidResponse("URL is missing from httpResponse or urlRequest")
                }

                // Convert header fields from [AnyHashable: Any] to [String: String]
                let headers: [String: String] = httpResponse.allHeaderFields.reduce(into: [:]) { dict, pair in
                    if let key = pair.key as? String,
                       let value = pair.value as? String {
                        dict[key] = value
                    }
                }

                return (statusCode: statusCode, url: url, headers: headers, httpBody: data)
            } catch is CancellationError {
                throw .cancelled
            } catch let error as URLError where error.code == .cancelled {
                // URLSession task cancellation
                throw .cancelled
            } catch let error as URLError where error.code == .timedOut {
                // URLSession timed out
                throw .timedOut
            } catch let error as URLError where error.code == .resourceUnavailable && cachePolicy == .returnCacheDataDontLoad {
                throw .cacheMiss
            } catch let error as URLError {
                throw .transport(error)
            } catch let error as NSError where error.domain == NSURLErrorDomain {
                let urlError = URLError(URLError.Code(rawValue: error.code), userInfo: error.userInfo)
                if urlError.code == .cancelled {
                    throw .cancelled
                } else if urlError.code == .timedOut {
                    throw .timedOut
                } else if urlError.code == .resourceUnavailable && cachePolicy == .returnCacheDataDontLoad {
                    throw .cacheMiss
                } else {
                    throw .transport(urlError)
                }
            } catch let error as ClientError {
                throw error
            } catch {
                throw .unknown(client: self, underlyingError: error)
            }
        }
    }

    nonisolated private func executeUploadRequest<Request: HTTPUploadRequest>(
        for request: Request,
        timeout: Duration
    ) -> @Sendable (Middleware.Request) async throws -> Middleware.Response {
        { [urlSession] middlewareRequest async throws(ClientError) -> Middleware.Response in
            if Task.isCancelled { throw .cancelled }

            guard let data = middlewareRequest.httpBody else {
                fatalError("There was no data to upload for request: \(Request.self)")
            }

            var urlRequest = request.createURLRequest(baseURL: middlewareRequest.baseURL)
            urlRequest.httpMethod = middlewareRequest.httpMethod.rawValue
            // Apply/override headers from middleware
            for (key, value) in middlewareRequest.headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }

            // Upload requests do not contain an HTTP body.
            urlRequest.httpBody = nil

            do {
                try Task.checkCancellation()
                let (data, response) = try await urlSession.upload(for: urlRequest, from: data)
                try Task.checkCancellation()

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ClientError.invalidResponse("Response was not an HTTP response")
                }

                guard let statusCode = HTTPStatusCode(rawValue: httpResponse.statusCode) else {
                    throw ClientError.invalidResponse("Invalid HTTP status code: \(httpResponse.statusCode)")
                }

                guard let url = httpResponse.url ?? urlRequest.url else {
                    throw ClientError.invalidResponse("URL is missing from httpResponse or urlRequest")
                }

                // Convert header fields from [AnyHashable: Any] to [String: String]
                let headers: [String: String] = httpResponse.allHeaderFields.reduce(into: [:]) { dict, pair in
                    if let key = pair.key as? String,
                       let value = pair.value as? String {
                        dict[key] = value
                    }
                }

                return (statusCode: statusCode, url: url, headers: headers, httpBody: data)
            } catch is CancellationError {
                throw .cancelled
            } catch let error as URLError where error.code == .cancelled {
                // URLSession task cancellation
                throw .cancelled
            } catch let error as URLError where error.code == .timedOut {
                // URLSession timed out
                throw .timedOut
            } catch let error as URLError {
                throw .transport(error)
            } catch let error as NSError where error.domain == NSURLErrorDomain {
                let urlError = URLError(URLError.Code(rawValue: error.code), userInfo: error.userInfo)
                if urlError.code == .cancelled {
                    throw .cancelled
                } else if urlError.code == .timedOut {
                    throw .timedOut
                } else {
                    throw .transport(urlError)
                }
            } catch let error as ClientError {
                throw error
            } catch {
                throw .unknown(client: self, underlyingError: error)
            }
        }
    }

    public func clearNetworkCache() async {
        let cache = urlSession.configuration.urlCache ?? URLCache.shared
        cache.removeAllCachedResponses()
    }
}

private extension URLSessionHTTPClient {
    // MARK: - Response Builders

    // General case: both Success and Failure exist
    private nonisolated func makeResponse<Request: HTTPRequest>(
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
    private nonisolated func makeResponse<Request: HTTPRequest>(
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
    private nonisolated func makeResponse<Request: HTTPRequest>(
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
