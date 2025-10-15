public import Foundation

/// A concrete HTTP client that uses `URLSession` to send requests and receive responses,
/// with support for a configurable base URL and a chain of middlewares.
/// 
/// `URLSessionHTTPClient` conforms to `HTTPClient` and is suitable for most networking
/// scenarios on Apple platforms. It encodes an `HTTPRequest` into a `URLRequest`,
/// executes it using the provided `URLSession`, and decodes the response body into
/// the expected `Request.ResponseBody`.
///
/// Features:
/// - Base URL composition for relative endpoints
/// - Pluggable middleware chain for request/response interception
/// - Configurable cache policy per request
/// - Cooperative cancellation checks during request execution
///
/// Thread-safety:
/// - The type is `nonisolated` and can be used across concurrency domains. Be mindful
///   that mutating `baseURL` or `middlewares` from multiple tasks at the same time
///   should be coordinated by the caller if needed. It is intended that you should mutate the baseurl and middle ware sparcely.
///   For example, when changing the app environment from prod to staging or develop. Or adding an authentication middleware after receiving a bearer token
///   from an auth api.
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

    @concurrent
    public func send<Request: HTTPRequest>(
        request: Request,
        cachePolicy: CachePolicy = .useProtocolCachePolicy,
        timeout: Duration = .seconds(30)
    ) async throws -> HTTPResponse<Request.ResponseBody> {
        try Task.checkCancellation()

        var next: @Sendable (Request, URL) async throws -> HTTPResponse<Request.ResponseBody> = { [urlSession] httpRequest, baseURL in
            var urlRequest = try httpRequest.encodeURLRequest(baseURL: baseURL)
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
            
            let body = try request.decodeResponseData(data)

            guard let url = httpResponse.url ?? urlRequest.url else {
                throw URLError(.unknown, userInfo: ["reason": "URL is missing from httpResponse or urlRequest"])
            }

            return HTTPResponse<Request.ResponseBody>(
                statusCode: statusCode,
                headers: httpResponse.allHeaderFields
                    .reduce(into: [String: String]()) { result, pair in
                        if let key = pair.key as? String,
                           let value = pair.value as? String {
                            result[key] = value
                        }
                    },
                url: url,
                httpBody: body,
                rawData: data
            )
        }
        
        for middleware in middlewares.reversed() {
            let tmp = next
            next = { urlRequest, baseURL in
                try Task.checkCancellation()
                return try await middleware.intercept(
                    request: urlRequest,
                    baseURL: baseURL,
                    next: tmp
                )
            }
        }
        
        let response = try await next(request, baseURL)
        try Task.checkCancellation()
        return response
    }
}

