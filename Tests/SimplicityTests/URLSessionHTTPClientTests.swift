import Foundation
import Testing
@testable import Simplicity

// MARK: - Tests

@Suite("URLSessionHTTPClient Tests")
struct URLSessionHTTPClientTests {
    let baseURL = URL(string: "https://example.com/api")!

    @Test
    func testSuccessDecoding_returnsModel() async throws {
        // Arrange
        let token = UUID().uuidString
        let tokenMiddleware = MiddlewareSpy { req in
            var req = req
            var headers = req.headers
            headers["X-Mock-Token"] = token
            req.headers = headers
            return req
        }
        let client = makeClient(baseURL: baseURL, middlewares: [tokenMiddleware])
        let expected = SuccessModel(value: "ok")
        MockURLProtocol.setHandler({ request in
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }, forToken: token)

        // Act
        let response = try await client.send(request: GetSuccessRequest())
        MockURLProtocol.removeHandler(forToken: token)

        // Assert
        let model = try JSONDecoder().decode(SuccessModel.self, from: response.httpBody)
        #expect(model == expected)
    }

    @Test
    func testFailureDecoding_returnsErrorPayload() async throws {
        // Arrange
        let token = UUID().uuidString
        let tokenMiddleware = MiddlewareSpy { req in
            var req = req
            var headers = req.headers
            headers["X-Mock-Token"] = token
            req.headers = headers
            return req
        }
        let client = makeClient(baseURL: baseURL, middlewares: [tokenMiddleware])
        let expected = ErrorModel(message: "bad")
        MockURLProtocol.setHandler({ request in
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }, forToken: token)

        // Act
        let response = try await client.send(request: GetSuccessRequest())
        MockURLProtocol.removeHandler(forToken: token)

        // Assert
        let err = try JSONDecoder().decode(ErrorModel.self, from: response.httpBody)
        #expect(err == expected)
    }

    @Test
    func testRequestBodyNoneWhenRequestBodyIsNever() async throws {
        // Arrange
        let token = UUID().uuidString
        let tokenMiddleware = MiddlewareSpy { req in
            var req = req
            var headers = req.headers
            headers["X-Mock-Token"] = token
            req.headers = headers
            return req
        }
        let client = makeClient(baseURL: baseURL, middlewares: [tokenMiddleware])
        MockURLProtocol.setHandler({ request in
            #expect(request.httpBody == nil)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }, forToken: token)

        // Act
        _ = try await client.send(request: GetSuccessRequest())
        MockURLProtocol.removeHandler(forToken: token)
    }

    @Test
    func testBaseURLComposition_usesClientBaseURLAndPath() async throws {
        // Arrange
        let token = UUID().uuidString
        let tokenMiddleware = MiddlewareSpy { req in
            var req = req
            var headers = req.headers
            headers["X-Mock-Token"] = token
            req.headers = headers
            return req
        }
        let client = makeClient(baseURL: baseURL, middlewares: [tokenMiddleware])
        MockURLProtocol.setHandler({ request in
            #expect(request.url?.absoluteString == "https://example.com/api/test/success")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }, forToken: token)

        // Act
        _ = try await client.send(request: GetSuccessRequest())
        MockURLProtocol.removeHandler(forToken: token)
    }

    @Test
    func testSpecialization_FailureIsNever_allowsSuccessOnly() async throws {
        // Arrange
        let token = UUID().uuidString
        let tokenMiddleware = MiddlewareSpy { req in
            var req = req
            var headers = req.headers
            headers["X-Mock-Token"] = token
            req.headers = headers
            return req
        }
        let client = makeClient(baseURL: baseURL, middlewares: [tokenMiddleware])
        let expected = SuccessModel(value: "ok")
        MockURLProtocol.setHandler({ request in
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }, forToken: token)

        // Act
        let response = try await client.send(request: SuccessOnlyRequest())
        MockURLProtocol.removeHandler(forToken: token)
        let model = try response.decodeSuccessBody()

        // Assert
        #expect(model == expected)
    }

    @Test
    func testSpecialization_SuccessIsNever_allowsFailureOnly() async throws {
        // Arrange
        let token = UUID().uuidString
        let tokenMiddleware = MiddlewareSpy { req in
            var req = req
            var headers = req.headers
            headers["X-Mock-Token"] = token
            req.headers = headers
            return req
        }
        let client = makeClient(baseURL: baseURL, middlewares: [tokenMiddleware])
        let expected = ErrorModel(message: "nope")
        MockURLProtocol.setHandler({ request in
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }, forToken: token)

        // Act
        let response = try await client.send(request: FailureOnlyRequest())
        MockURLProtocol.removeHandler(forToken: token)
        let err = try response.decodeFailureBody()

        // Assert
        #expect(err == expected)
    }
}

// MARK: - Helpers

private func makeClient(baseURL: URL, middlewares: [any Middleware] = []) -> URLSessionHTTPClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)
    return URLSessionHTTPClient(urlSession: session, baseURL: baseURL, middlewares: middlewares)
}

// MARK: - Test Requests

private struct SuccessModel: Codable, Sendable, Equatable { let value: String }
private struct ErrorModel: Codable, Sendable, Equatable { let message: String }

private struct GetSuccessRequest: HTTPRequest {
    typealias RequestBody = Never
    typealias SuccessResponseBody = SuccessModel
    typealias FailureResponseBody = ErrorModel

    static var operationID: String { "success" }
    var httpMethod: HTTPMethod { .get }
    var path: String { "/test/success" }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }

    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = httpMethod.rawValue
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }

    func decodeSuccessResponseData(_ data: Data) throws -> SuccessModel {
        try JSONDecoder().decode(SuccessModel.self, from: data)
    }

    func decodeFailureResponseData(_ data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

private struct PostWithBodyRequest: HTTPRequest {
    typealias RequestBody = SuccessModel
    typealias SuccessResponseBody = SuccessModel
    typealias FailureResponseBody = ErrorModel

    static var operationID: String { "body" }
    var httpMethod: HTTPMethod { .post }
    var path: String { "/test/body" }
    var headers: [String: String] { ["Content-Type": "application/json"] }
    var queryItems: [URLQueryItem] {[]}
    var httpBody: SuccessModel

    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = httpMethod.rawValue
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }

    func encodeHTTPBody() throws -> Data? {
        try JSONEncoder().encode(httpBody)
    }

    func decodeSuccessResponseData(_ data: Data) throws -> SuccessModel {
        try JSONDecoder().decode(SuccessModel.self, from: data)
    }

    func decodeFailureResponseData(_ data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

private struct FailureOnlyRequest: HTTPRequest {
    typealias RequestBody = Never
    typealias SuccessResponseBody = Never
    typealias FailureResponseBody = ErrorModel

    static var operationID: String { "failure" }
    var httpMethod: HTTPMethod { .get }
    var path: String { "/test/failure-only" }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }

    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = httpMethod.rawValue
        return req
    }

    func encodeHTTPBody() throws -> Data? { nil }

    func decodeSuccessResponseData(_ data: Data) throws -> Never {
        fatalError("should not decode success for FailureOnlyRequest")
    }

    func decodeFailureResponseData(_ data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

private struct SuccessOnlyRequest: HTTPRequest {
    typealias RequestBody = Never
    typealias SuccessResponseBody = SuccessModel
    typealias FailureResponseBody = Never

    static var operationID: String { "success-only" }
    var httpMethod: HTTPMethod { .get }
    var path: String { "/test/success-only" }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }

    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = httpMethod.rawValue
        return req
    }

    func encodeHTTPBody() throws -> Data? { nil }

    func decodeSuccessResponseData(_ data: Data) throws -> SuccessModel {
        try JSONDecoder().decode(SuccessModel.self, from: data)
    }

    func decodeFailureResponseData(_ data: Data) throws -> Never {
        fatalError("should not decode failure for SuccessOnlyRequest")
    }
}
