import Foundation
import Testing
import XCTest
import Simplicity


@Suite("Middleware tests", .serialized)
struct MiddlewareTests {
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    struct MockRequest: HTTPRequest {
        typealias RequestBody = Never?
        typealias ResponseBody = String

        static let operationID: String = "Test"
        var path: String { "/test" }
        var httpMethod: Simplicity.HTTPMethod { .get }
        var headers: [String : String] { [:] }
        var queryItems: [URLQueryItem] { [] }
        var httpBody: Never? { nil }

        func encodeURLRequest(baseURL: URL) throws -> URLRequest {
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
    
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test("Middleware call order is correct")
    func middlewareCallOrder() async throws {
        let middleware1 = MiddlewareSpy()
        let middleware2 = MiddlewareSpy()
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "\"Test\"".data(using: .utf8)
            return (response, data)
        }
        
        let client = HTTPClient(
            urlSession: session,
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [middleware1, middleware2]
        )
        
        let request = MockRequest()
        
        let _ = try await client.send(request: request)
        let callTime1 = try #require(await middleware1.callTime)
        let callTime2 = try #require(await middleware2.callTime)
        #expect(callTime1 <= callTime2)
    }
    
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test("Middleware does correctly mutate value")
    func middlewareMutation() async throws {
        let middleware = MiddlewareSpy { request, baseURL, operationID in
            var request = request
            request.allHTTPHeaderFields = ["accepts": "application/json"]
            return (request, baseURL, operationID)
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        MockURLProtocol.requestHandler = { request in
            #expect(request.allHTTPHeaderFields?["accepts"] == "application/json")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "\"Test\"".data(using: .utf8)
            return (response, data)
        }
        
        let client = HTTPClient(
            urlSession: session,
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [middleware]
        )
        
        let request = MockRequest()
        
        let _ = try await client.send(request: request)
    }
    
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test("Post middleware is called after the request completion")
    func postMiddlewareCallOrder() async throws {
        let middleware = MiddlewareSpy(
            mutation: nil,
            postResponseOperation: { data, response in
                do {
                    let dataString = try #require(String(data: data, encoding: .utf8))
                    #expect(dataString == "\"Test\"")
                    #expect(response.statusCode == 200)
                } catch {
                    Issue.record(error)
                }
            }
        )
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "\"Test\"".data(using: .utf8)
            return (response, data)
        }
        
        let client = HTTPClient(
            urlSession: session,
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [middleware]
        )
        
        let request = MockRequest()
        
        let _ = try await client.send(request: request)
    }
}

