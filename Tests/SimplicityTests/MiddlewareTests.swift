import Foundation
import Testing
import XCTest
import Simplicity

@Suite("Middleware tests")
struct MiddlewareTests {
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    struct MockRequest: HTTPRequest {
        typealias RequestBody = Never?
        typealias ResponseBody = String

        static let operationID: String = "Test"
        var path: String { "/test" }
        var httpMethod: Simplicity.HTTPMethod = .get
        var headers: [String : String] = [:]
        var queryItems: [URLQueryItem] = []

        func createURLRequest(baseURL: URL) -> URLRequest {
            let url = baseURL.appending(path: path).appending(queryItems: queryItems)
            var urlRequest = URLRequest(url: url)
            urlRequest.allHTTPHeaderFields = headers
            urlRequest.httpMethod = httpMethod.rawValue
            return urlRequest
        }
        
        func decodeResponseData(_ data: Data) throws -> String {
            try JSONDecoder().decode(String.self, from: data)
        }
    }
    
    @Test("Middleware call order is correct")
    func middlewareCallOrder() async throws {
        let middleware1 = MiddlewareSpy()
        let middleware2 = MiddlewareSpy()
        
        let token = UUID().uuidString
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.setHandler({ request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "\"Test\"".data(using: .utf8)
            return (response, data)
        }, forToken: token)
        
        let client = URLSessionHTTPClient(
            urlSession: session,
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [
                MiddlewareSpy { req in
                    var req = req
                    var headers = req.headers
                    headers["X-Mock-Token"] = token
                    req.headers = headers
                    return req
                },
                middleware1,
                middleware2
            ]
        )
        
        let request = MockRequest()
        
        let _ = try await client.send(request: request)
        MockURLProtocol.removeHandler(forToken: token)
        
        let callTime1 = try #require(await middleware1.callTime)
        let callTime2 = try #require(await middleware2.callTime)
        #expect(callTime1 <= callTime2)
    }

    @Test("Middleware does correctly mutate value")
    func middlewareMutation() async throws {
        let middleware = MiddlewareSpy { request in
            var request = request
            var headers = request.headers
            headers["accepts"] = "application/json"
            request.headers = headers
            return request
        }
        
        let token = UUID().uuidString
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        MockURLProtocol.setHandler({ request in
            #expect(request.allHTTPHeaderFields?["accepts"] == "application/json")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "\"Test\"".data(using: .utf8)
            return (response, data)
        }, forToken: token)
        
        let client = URLSessionHTTPClient(
            urlSession: session,
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [
                MiddlewareSpy { req in
                    var req = req
                    var headers = req.headers
                    headers["X-Mock-Token"] = token
                    req.headers = headers
                    return req
                },
                middleware
            ]
        )
        
        let request = MockRequest()
        
        let _ = try await client.send(request: request)
        MockURLProtocol.removeHandler(forToken: token)
    }

    @Test("Post middleware is called after the request completion")
    func postMiddlewareCallOrder() async throws {
        let middleware = MiddlewareSpy(
            mutation: nil,
            postResponseOperation: { response in
                do {
                    let responseBody = try #require(String(data: response.httpBody, encoding: .utf8))
                    #expect(responseBody == "\"Test\"")
                } catch {
                    Issue.record(error, "Response body was invalid")
                }

                #expect(response.statusCode == .ok)
            }
        )
        
        // Use the shared MockURLProtocol with a per-test token to isolate the handler
        let token = UUID().uuidString
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        // Register a token-specific handler
        MockURLProtocol.setHandler({ request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "\"Test\"".data(using: .utf8)
            return (response, data)
        }, forToken: token)

        // Middleware to inject the token header so the protocol picks the right handler
        let tokenHeaderMiddleware = MiddlewareSpy { request in
            var request = request
            var headers = request.headers
            headers["X-Mock-Token"] = token
            request.headers = headers
            return request
        }

        let client = URLSessionHTTPClient(
            urlSession: session,
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [tokenHeaderMiddleware, middleware]
        )

        let request = MockRequest()

        let _ = try await client.send(request: request)

        // Optional: clean up the handler for this token after the test
        MockURLProtocol.removeHandler(forToken: token)
    }
}
