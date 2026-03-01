import Foundation
import Testing
import HTTPTypes
import Simplicity

@Suite("Middleware tests")
struct MiddlewareTests {
    struct MockRequest: Request {
        typealias RequestBody = Never?

        static let operationID: String = "Test"
        var path: String { "/test" }
        var method: HTTPRequest.Method = .get
        var headerFields: HTTPFields = HTTPFields()
        var queryItems: [URLQueryItem] = []
    }

    @Test("Middleware call order is correct")
    func middlewareCallOrder() async throws {
        let middleware1 = MiddlewareSpy()
        let middleware2 = MiddlewareSpy()

        let client = URLSessionClient(
            transport: MockTransport { _, _ in
                ("\"Test\"".data(using: .utf8)!, HTTPResponse(status: .ok))
            },
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [middleware1, middleware2]
        )

        let request = MockRequest()

        let _ = try await client.send(request)

        let callTime1 = try #require(await middleware1.callTime)
        let callTime2 = try #require(await middleware2.callTime)
        #expect(callTime1 <= callTime2)
    }

    @Test("Middleware does correctly mutate value")
    func middlewareMutation() async throws {
        let middleware = MiddlewareSpy { request in
            var request = request
            request.httpRequest.headerFields[HTTPField.Name("accepts")!] = "application/json"
            return request
        }

        let client = URLSessionClient(
            transport: MockTransport { request, _ in
                #expect(request.headerFields[HTTPField.Name("accepts")!] == "application/json")
                return ("\"Test\"".data(using: .utf8)!, HTTPResponse(status: .ok))
            },
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [middleware]
        )

        let request = MockRequest()

        let _ = try await client.send(request)
    }

    @Test("Post middleware is called after the request completion")
    func postMiddlewareCallOrder() async throws {
        let middleware = MiddlewareSpy(
            mutation: nil,
            postResponseOperation: { response in
                do {
                    let responseBody = try #require(String(data: response.body, encoding: .utf8))
                    #expect(responseBody == "\"Test\"")
                } catch {
                    Issue.record(error, "Response body was invalid")
                }

                #expect(response.httpResponse.status == .ok)
            }
        )

        let client = URLSessionClient(
            transport: MockTransport { _, _ in
                ("\"Test\"".data(using: .utf8)!, HTTPResponse(status: .ok))
            },
            baseURL: URL(string: "https://www.google.com")!,
            middlewares: [middleware]
        )

        let request = MockRequest()

        let _ = try await client.send(request)
    }
}
