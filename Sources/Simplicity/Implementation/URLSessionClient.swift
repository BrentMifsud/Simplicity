public import Foundation
public import HTTPTypes
import HTTPTypesFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A concrete HTTP client that uses `URLSession` to send requests and receive responses,
/// with support for a configurable base URL and a chain of middlewares.
///
/// `URLSessionClient` conforms to `Client` and is suitable for most networking
/// scenarios on Apple platforms. It encodes a `Request` into an `HTTPRequest`,
/// executes it using the provided `URLSession`, and produces a `Response<Success, Failure>`
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
/// - The type is an `actor` and can be used safely across concurrency domains. Properties
///   like `baseURL` and `middlewares` are intended to be changed sparingly (e.g., when switching
///   environments or installing auth middleware after obtaining a bearer token).
public actor URLSessionClient: Client {
    let transport: any Transport
    let urlCache: URLCache?
    public private(set) var baseURL: URL
    public private(set) var middlewares: [any Middleware]

    /// Initializes a new client instance with a custom transport.
    /// - Parameters:
    ///   - transport: The transport to use for network requests. Defaults to ``URLSessionTransport``.
    ///   - urlCache: The URL cache for cache management methods. Defaults to `nil` (falls back to `URLCache.shared`).
    ///   - baseURL: The base URL for HTTP requests.
    ///   - middlewares: Middlewares for intercepting and modifying requests/responses.
    public init(
        transport: any Transport = URLSessionTransport(),
        urlCache: URLCache? = nil,
        baseURL: URL,
        middlewares: [any Middleware]
    ) {
        self.transport = transport
        self.urlCache = urlCache
        self.baseURL = baseURL
        self.middlewares = middlewares
    }

    /// Convenience initializer that wraps a `URLSession` in a ``URLSessionTransport``.
    /// - Parameters:
    ///   - urlSession: The URLSession to use.
    ///   - baseURL: The base URL for HTTP requests.
    ///   - middlewares: Middlewares for intercepting and modifying requests/responses.
    public init(urlSession: URLSession, baseURL: URL, middlewares: [any Middleware]) {
        self.transport = URLSessionTransport(session: urlSession)
        self.urlCache = urlSession.configuration.urlCache
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
    /// - Parameters:
    ///   - request: The typed request to send.
    ///   - cachePolicy: Cache policy to apply. Defaults to `.useProtocolCachePolicy`.
    ///   - timeout: Timeout for the request. Defaults to 30 seconds.
    /// - Returns: A `Response` carrying status, headers, final URL, raw bytes, and decoders.
    /// - Throws: Any error thrown during request encoding, middleware processing, network transfer,
    ///   or response handling.
    @concurrent
    public func send<R: Request>(
        _ request: R,
        cachePolicy: CachePolicy = .useProtocolCachePolicy,
        timeout: Duration = .seconds(30)
    ) async throws(ClientError) -> Response<R.SuccessResponseBody, R.FailureResponseBody> {
        if Task.isCancelled { throw ClientError.cancelled }

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
        if R.RequestBody.self == Never.self || R.RequestBody.self == Never?.self {
            requestBody = nil
        } else {
            do {
                requestBody = try request.encodeBody()
            } catch {
                throw ClientError.encodingError(type: "\(R.RequestBody.self)", underlyingError: error)
            }
        }

        let httpRequest = request.makeHTTPRequest(baseURL: await baseURL)

        let initialMiddlewareRequest = MiddlewareRequest(
            httpRequest: httpRequest,
            body: requestBody,
            operationID: type(of: request).operationID,
            baseURL: await baseURL,
            cachePolicy: cachePolicy
        )

        do {
            if Task.isCancelled { throw ClientError.cancelled }
            let response = try await next(initialMiddlewareRequest)
            return makeResponse(
                httpResponse: response.httpResponse,
                url: response.url,
                body: response.body,
                for: request
            )
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError.unknown(client: self, underlyingError: error)
        }
    }

    public func upload<R: UploadRequest>(
        _ request: R,
        timeout: Duration = .seconds(30)
    ) async throws(ClientError) -> Response<R.SuccessResponseBody, R.FailureResponseBody> {
        if Task.isCancelled { throw ClientError.cancelled }

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
            throw ClientError.encodingError(type: "\(R.self)", underlyingError: error)
        }

        let httpRequest = request.makeHTTPRequest(baseURL: baseURL)

        let initialMiddlewareRequest = MiddlewareRequest(
            httpRequest: httpRequest,
            body: uploadData,
            operationID: type(of: request).operationID,
            baseURL: baseURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData // Uploads bypass cache
        )

        do {
            if Task.isCancelled { throw ClientError.cancelled }
            let response = try await next(initialMiddlewareRequest)
            return makeResponse(
                httpResponse: response.httpResponse,
                url: response.url,
                body: response.body,
                for: request
            )
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError.unknown(client: self, underlyingError: error)
        }
    }

    nonisolated private func executeURLRequest<R: Request>(
        for request: R,
        cachePolicy: CachePolicy,
        timeout: Duration
    ) -> @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse {
        { [transport] middlewareRequest async throws(ClientError) -> MiddlewareResponse in
            if Task.isCancelled { throw .cancelled }

            do {
                try Task.checkCancellation()
                let (data, httpResponse, url) = try await transport.data(
                    for: middlewareRequest.httpRequest,
                    body: middlewareRequest.body,
                    cachePolicy: cachePolicy,
                    timeout: timeout
                )
                try Task.checkCancellation()

                return MiddlewareResponse(
                    httpResponse: httpResponse,
                    url: url,
                    body: data
                )
            } catch is CancellationError {
                throw .cancelled
            } catch let error as URLError where error.code == .cancelled {
                throw .cancelled
            } catch let error as URLError where error.code == .timedOut {
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
            } catch let error as NSError {
                if let underlyingURLError = error.userInfo[NSUnderlyingErrorKey] as? URLError {
                    if underlyingURLError.code == .cancelled {
                        throw .cancelled
                    } else if underlyingURLError.code == .timedOut {
                        throw .timedOut
                    } else if underlyingURLError.code == .resourceUnavailable && cachePolicy == .returnCacheDataDontLoad {
                        throw .cacheMiss
                    } else {
                        throw .transport(underlyingURLError)
                    }
                }
                throw .unknown(client: self, underlyingError: error)
            } catch {
                throw .unknown(client: self, underlyingError: error)
            }
        }
    }

    nonisolated private func executeUploadRequest<R: UploadRequest>(
        for request: R,
        timeout: Duration
    ) -> @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse {
        { [transport] middlewareRequest async throws(ClientError) -> MiddlewareResponse in
            if Task.isCancelled { throw .cancelled }

            guard let data = middlewareRequest.body else {
                fatalError("There was no data to upload for request: \(R.self)")
            }

            do {
                try Task.checkCancellation()
                let (responseData, httpResponse, url) = try await transport.upload(
                    for: middlewareRequest.httpRequest,
                    from: data,
                    timeout: timeout
                )
                try Task.checkCancellation()

                return MiddlewareResponse(
                    httpResponse: httpResponse,
                    url: url,
                    body: responseData
                )
            } catch is CancellationError {
                throw .cancelled
            } catch let error as URLError where error.code == .cancelled {
                throw .cancelled
            } catch let error as URLError where error.code == .timedOut {
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
            } catch let error as NSError {
                if let underlyingURLError = error.userInfo[NSUnderlyingErrorKey] as? URLError {
                    if underlyingURLError.code == .cancelled {
                        throw .cancelled
                    } else if underlyingURLError.code == .timedOut {
                        throw .timedOut
                    } else {
                        throw .transport(underlyingURLError)
                    }
                }
                throw .unknown(client: self, underlyingError: error)
            } catch {
                throw .unknown(client: self, underlyingError: error)
            }
        }
    }

    public func clearNetworkCache() async {
        let cache = urlCache ?? .shared
        cache.removeAllCachedResponses()
    }

    // MARK: - Cache Management

    public func setCachedResponse<R: Request>(
        _ responseBody: R.SuccessResponseBody,
        for request: R,
        status: HTTPResponse.Status = .ok,
        headerFields: HTTPFields = HTTPFields()
    ) async throws(ClientError) where R.SuccessResponseBody: Encodable {
        let cache = urlCache ?? .shared
        let url = request.requestURL(baseURL: baseURL)
        let urlRequest = URLRequest(url: url)

        let data: Data
        do {
            let encoder = JSONEncoder()
            data = try encoder.encode(responseBody)
        } catch {
            throw .encodingError(type: "\(R.SuccessResponseBody.self)", underlyingError: error)
        }

        // Convert HTTPFields to [String: String] for HTTPURLResponse construction
        var headerDict: [String: String] = [:]
        for field in headerFields {
            headerDict[field.name.rawName] = field.value
        }
        if headerDict["Content-Type"] == nil {
            headerDict["Content-Type"] = "application/json"
        }

        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: status.code,
            httpVersion: "HTTP/1.1",
            headerFields: headerDict
        ) else {
            throw .invalidResponse("Failed to create HTTPURLResponse for caching")
        }

        let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
        cache.storeCachedResponse(cachedResponse, for: urlRequest)
    }

    public func cachedResponse<R: Request>(
        for request: R
    ) async throws(ClientError) -> Response<R.SuccessResponseBody, R.FailureResponseBody> {
        let cache = urlCache ?? .shared
        let url = request.requestURL(baseURL: baseURL)
        let urlRequest = URLRequest(url: url)

        guard let cachedResponse = cache.cachedResponse(for: urlRequest),
              let httpURLResponse = cachedResponse.response as? HTTPURLResponse,
              let httpResponse = httpURLResponse.httpResponse else {
            throw .cacheMiss
        }

        return makeResponse(
            httpResponse: httpResponse,
            url: url,
            body: cachedResponse.data,
            for: request
        )
    }

    public func removeCachedResponse<R: Request>(
        for request: R
    ) async {
        let cache = urlCache ?? .shared
        let url = request.requestURL(baseURL: baseURL)
        let urlRequest = URLRequest(url: url)
        cache.removeCachedResponse(for: urlRequest)
    }
}

private extension URLSessionClient {
    // MARK: - Response Builders

    // General case: both Success and Failure exist
    private nonisolated func makeResponse<R: Request>(
        httpResponse: HTTPResponse,
        url: URL,
        body: Data,
        for request: R
    ) -> Response<R.SuccessResponseBody, R.FailureResponseBody> {
        Response(
            httpResponse: httpResponse,
            url: url,
            body: body,
            successBodyDecoder: { data in
                try request.decodeSuccessBody(from: data)
            },
            failureBodyDecoder: { data in
                try request.decodeFailureBody(from: data)
            }
        )
    }

    // Specialized: Failure == Never (success-only)
    private nonisolated func makeResponse<R: Request>(
        httpResponse: HTTPResponse,
        url: URL,
        body: Data,
        for request: R
    ) -> Response<R.SuccessResponseBody, R.FailureResponseBody>
    where R.FailureResponseBody == Never {
        Response(
            httpResponse: httpResponse,
            url: url,
            body: body,
            successBodyDecoder: { data in
                try request.decodeSuccessBody(from: data)
            }
        )
    }

    // Specialized: Success == Never (failure-only)
    private nonisolated func makeResponse<R: Request>(
        httpResponse: HTTPResponse,
        url: URL,
        body: Data,
        for request: R
    ) -> Response<R.SuccessResponseBody, R.FailureResponseBody>
    where R.SuccessResponseBody == Never {
        Response(
            httpResponse: httpResponse,
            url: url,
            body: body,
            failureBodyDecoder: { data in
                try request.decodeFailureBody(from: data)
            }
        )
    }
}
