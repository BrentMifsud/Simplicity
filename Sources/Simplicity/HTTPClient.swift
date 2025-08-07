import Foundation

/// An asynchronous HTTP client that supports middleware for request/response interception and transformation.
///
/// Example usage:
/// ```swift
/// let client = HTTPClient(baseURL: URL(string: "https://api.example.com")!, middlewares: [MyLoggingMiddleware()])
/// let request = GetUserRequest(userID: "1234")
/// let user = try await client.send(request: request)
/// ```
public struct HTTPClient {
    /// The underlying URLSession used to perform requests.
    public let urlSession: URLSession
    /// The base URL used for all requests.
    public let baseURL: URL
    /// The middleware chain used to intercept, modify, or observe requests and responses.
    public let middlewares: [any Middleware]
    
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
    
    /// Sends an HTTP request using the middleware chain, returning the decoded response body.
    ///
    /// This method builds the middleware chain, constructs a `URLRequest`, and performs the network call. Each middleware may intercept, modify, or observe the request and response. The final response data is decoded into the expected response type.
    ///
    /// - Parameter request: The request conforming to `HTTPRequest` to send.
    /// - Returns: The decoded response body of type `Request.ResponseBody`.
    /// - Throws: Any error thrown by the request encoding, network transport, middleware, or response decoding.
    public func send<Request: HTTPRequest>(request: Request) async throws -> Request.ResponseBody {
        var next: @Sendable (URLRequest, URL, String) async throws -> (Data, HTTPURLResponse) = { [urlSession] (request, body, url) in
            let (data, response) = try await urlSession.data(for: request)
            
            try Task.checkCancellation()
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.unknown, userInfo: ["reason" : "Response was not an HTTP response"])
            }
            
            return (data, httpResponse)
        }
        
        for middleware in middlewares.reversed() {
            let tmp = next
            next = { (request, baseURL, operationID) in
                try await middleware.intercept(
                    request: request,
                    baseURL: baseURL,
                    operationID: operationID,
                    next: tmp
                )
            }
        }
        
        let urlRequest = try request.encodeURLRequest(baseURL: baseURL)
        let (data, _) = try await next(urlRequest, baseURL, type(of: request).operationID)
        return try request.decodeResponseData(data)
    }
}
