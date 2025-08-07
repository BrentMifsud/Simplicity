import Foundation

public actor HTTPClient {
    typealias Request = Encodable & Sendable
    typealias Response = Decodable & Sendable
    
    private(set) var urlSession: URLSession
    private(set) var baseURL: URL
    private(set) var middlewares: [any Middleware]
    
    init(urlSession: URLSession = .shared, baseURL: URL, middlewares: [any Middleware]) {
        self.urlSession = urlSession
        self.baseURL = baseURL
        self.middlewares = middlewares
    }
    
    func send<Request: HTTPRequest>(request: Request) async throws -> Request.ResponseBody {
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
