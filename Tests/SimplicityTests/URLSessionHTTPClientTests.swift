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

    @Test
    func testMiddlewareNonClientError_isWrappedAsMiddlewareAndNotNested() async throws {
        // Arrange
        enum DummyError: Error, Equatable { case boom }
        let throwingMiddleware = MiddlewareSpy(thrownError: DummyError.boom)
        let client = makeClient(baseURL: baseURL, middlewares: [throwingMiddleware])

        // Act
        do {
            _ = try await client.send(request: GetSuccessRequest())
            Issue.record("Expected to throw, but succeeded")
        } catch {
            // Assert: should be wrapped as .middleware with underlying DummyError
            switch error {
            case .middleware(let mw, let underlyingError):
                #expect((mw as? MiddlewareSpy) === throwingMiddleware)
                #expect((underlyingError as? DummyError) == .boom)
                assertNoNestedClientError(error)
            default:
                Issue.record("Expected ClientError.middleware, got: \(error)")
            }
        }
    }

    @Test
    func testMiddlewareClientError_isNotWrapped() async throws {
        // Arrange
        let middleware = MiddlewareSpy(thrownError: ClientError.invalidResponse("forced"))
        let client = makeClient(baseURL: baseURL, middlewares: [middleware])

        // Act
        do {
            _ = try await client.send(request: GetSuccessRequest())
            Issue.record("Expected to throw, but succeeded")
        } catch {
            // Assert: should be the exact same ClientError, not wrapped
            switch error {
            case .invalidResponse(let message):
                #expect(message == "forced")
                assertNoNestedClientError(error)
            default:
                Issue.record("Expected ClientError.invalidResponse, got: \(error)")
            }
        }
    }

    @Test
    func testURLSessionURLError_isWrappedAsTransport() async throws {
        // Arrange
        let token = UUID().uuidString
        defer { MockURLProtocol.removeHandler(forToken: token) }
        let tokenMiddleware = MiddlewareSpy { req in
            var req = req
            var headers = req.headers
            headers["X-Mock-Token"] = token
            req.headers = headers
            return req
        }
        let client = makeClient(baseURL: baseURL, middlewares: [tokenMiddleware])
        MockURLProtocol.setHandler({ _ in
            throw URLError(.badServerResponse)
        }, forToken: token)

        // Act
        do {
            _ = try await client.send(request: GetSuccessRequest())
            Issue.record("Expected to throw, but succeeded")
        } catch {
            // Assert
            switch error {
            case .transport(let urlError):
                #expect(urlError.code == .badServerResponse)
                assertNoNestedClientError(error)
            default:
                Issue.record("Expected ClientError.transport, got: \(error)")
            }
        }
    }

    @Test
    func testInvalidStatusCode_isInvalidResponse() async throws {
        // Arrange
        let token = UUID().uuidString
        defer { MockURLProtocol.removeHandler(forToken: token) }
        let tokenMiddleware = MiddlewareSpy { req in
            var req = req
            var headers = req.headers
            headers["X-Mock-Token"] = token
            req.headers = headers
            return req
        }
        let client = makeClient(baseURL: baseURL, middlewares: [tokenMiddleware])
        MockURLProtocol.setHandler({ request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 999, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }, forToken: token)

        // Act
        do {
            _ = try await client.send(request: GetSuccessRequest())
            Issue.record("Expected to throw, but succeeded")
        } catch {
            // Assert
            if case let .invalidResponse(message) = error {
                #expect(message.contains("Invalid HTTP status code"))
            } else {
                Issue.record(error, "Expected an invalidResponse error")
            }
            assertNoNestedClientError(error)
        }
    }

    // MARK: - Assertions
    private func assertNoNestedClientError(
        _ error: ClientError,
        sourceLocation: SourceLocation = SourceLocation(
            fileID: #fileID,
            filePath: #filePath,
            line: #line,
            column: #column
        )
    ) {
        switch error {
        case .middleware(_, let underlying):
            #expect(!(underlying is ClientError), "ClientError.middleware should not wrap a ClientError")
        case .encodingError(let underlying):
            #expect(
                !(underlying is ClientError),
                "ClientError.encodingError should not wrap a ClientError",
                sourceLocation: sourceLocation
            )
        case .unknown(_, let underlying):
            #expect(
                !(underlying is ClientError),
                "ClientError.unknown should not wrap a ClientError",
                sourceLocation: sourceLocation
            )
        default:
            break
        }
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

    func createURLRequest(baseURL: URL) -> URLRequest {
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

    func createURLRequest(baseURL: URL) -> URLRequest {
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

    func createURLRequest(baseURL: URL) -> URLRequest {
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

    func createURLRequest(baseURL: URL) -> URLRequest {
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

// MARK: - Cache Tests

@Suite("URLSessionHTTPClient Cache Tests")
struct URLSessionHTTPClientCacheTests {
    let baseURL = URL(string: "https://example.com/api")!

    @Test
    func testSetCachedResponse_storesInCache() async throws {
        // Arrange
        let client = makeCacheableClient(baseURL: baseURL)
        let expected = CacheableModel(id: 1, name: "cached")

        // Act
        try await client.setCachedResponse(expected, for: CacheableRequest())

        // Assert - retrieve and verify
        let cached = try await client.cachedResponse(for: CacheableRequest())
        let decoded = try cached.decodeSuccessBody()
        #expect(decoded == expected)
    }

    @Test
    func testCachedResponse_throwsCacheMiss_whenNotCached() async throws {
        // Arrange
        let client = makeCacheableClient(baseURL: baseURL)

        // Act & Assert
        do {
            _ = try await client.cachedResponse(for: CacheableRequest())
            Issue.record("Expected cacheMiss error")
        } catch {
            guard case .cacheMiss = error else {
                Issue.record("Expected cacheMiss, got: \(error)")
                return
            }
        }
    }

    @Test
    func testRemoveCachedResponse_clearsCache() async throws {
        // Arrange
        let client = makeCacheableClient(baseURL: baseURL)
        let model = CacheableModel(id: 2, name: "to-remove")
        try await client.setCachedResponse(model, for: CacheableRequest())

        // Verify it's cached
        _ = try await client.cachedResponse(for: CacheableRequest())

        // Act
        await client.removeCachedResponse(for: CacheableRequest())

        // Assert - should now throw cacheMiss
        do {
            _ = try await client.cachedResponse(for: CacheableRequest())
            Issue.record("Expected cacheMiss error after removal")
        } catch {
            guard case .cacheMiss = error else {
                Issue.record("Expected cacheMiss, got: \(error)")
                return
            }
        }
    }

    @Test
    func testCachedResponse_preservesStatusCode() async throws {
        // Arrange
        let client = makeCacheableClient(baseURL: baseURL)
        let model = CacheableModel(id: 3, name: "with-status")

        // Act
        try await client.setCachedResponse(model, for: CacheableRequest(), statusCode: .created)
        let cached = try await client.cachedResponse(for: CacheableRequest())

        // Assert
        #expect(cached.statusCode == .created)
    }

    @Test
    func testCachedResponse_preservesHeaders() async throws {
        // Arrange
        let client = makeCacheableClient(baseURL: baseURL)
        let model = CacheableModel(id: 4, name: "with-headers")
        let headers = ["Content-Type": "application/json", "X-Custom": "value"]

        // Act
        try await client.setCachedResponse(model, for: CacheableRequest(), headers: headers)
        let cached = try await client.cachedResponse(for: CacheableRequest())

        // Assert
        #expect(cached.headers["X-Custom"] == "value")
    }

    @Test
    func testCachedResponse_differentQueryParams_differentCacheEntries() async throws {
        // Arrange
        let client = makeCacheableClient(baseURL: baseURL)
        let model1 = CacheableModel(id: 10, name: "query1")
        let model2 = CacheableModel(id: 20, name: "query2")

        // Act - cache with different query params
        try await client.setCachedResponse(model1, for: CacheableRequestWithQuery(filter: "a"))
        try await client.setCachedResponse(model2, for: CacheableRequestWithQuery(filter: "b"))

        // Assert - each query should have its own cache entry
        let cached1 = try await client.cachedResponse(for: CacheableRequestWithQuery(filter: "a"))
        let cached2 = try await client.cachedResponse(for: CacheableRequestWithQuery(filter: "b"))

        #expect(try cached1.decodeSuccessBody() == model1)
        #expect(try cached2.decodeSuccessBody() == model2)
    }

    @Test
    func testClearNetworkCache_clearsAllCachedResponses() async throws {
        // Arrange
        let client = makeCacheableClient(baseURL: baseURL)
        let model = CacheableModel(id: 5, name: "to-clear")
        try await client.setCachedResponse(model, for: CacheableRequest())

        // Act
        await client.clearNetworkCache()

        // Assert - should now throw cacheMiss
        do {
            _ = try await client.cachedResponse(for: CacheableRequest())
            Issue.record("Expected cacheMiss error after clear")
        } catch {
            guard case .cacheMiss = error else {
                Issue.record("Expected cacheMiss, got: \(error)")
                return
            }
        }
    }
}

// MARK: - Cache Test Helpers

private func makeCacheableClient(baseURL: URL) -> URLSessionHTTPClient {
    let config = URLSessionConfiguration.ephemeral
    config.urlCache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
    let session = URLSession(configuration: config)
    return URLSessionHTTPClient(urlSession: session, baseURL: baseURL, middlewares: [])
}

private struct CacheableModel: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

private struct CacheableRequest: HTTPRequest {
    typealias RequestBody = Never
    typealias SuccessResponseBody = CacheableModel
    typealias FailureResponseBody = ErrorModel

    static var operationID: String { "cacheable" }
    var httpMethod: HTTPMethod { .get }
    var path: String { "/test/cacheable" }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }

    func createURLRequest(baseURL: URL) -> URLRequest {
        var req = URLRequest(url: requestURL(baseURL: baseURL))
        req.httpMethod = httpMethod.rawValue
        return req
    }

    func decodeSuccessResponseData(_ data: Data) throws -> CacheableModel {
        try JSONDecoder().decode(CacheableModel.self, from: data)
    }

    func decodeFailureResponseData(_ data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

private struct CacheableRequestWithQuery: HTTPRequest {
    typealias RequestBody = Never
    typealias SuccessResponseBody = CacheableModel
    typealias FailureResponseBody = ErrorModel

    let filter: String

    static var operationID: String { "cacheable-query" }
    var httpMethod: HTTPMethod { .get }
    var path: String { "/test/cacheable" }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "filter", value: filter)] }

    func createURLRequest(baseURL: URL) -> URLRequest {
        var req = URLRequest(url: requestURL(baseURL: baseURL))
        req.httpMethod = httpMethod.rawValue
        return req
    }

    func decodeSuccessResponseData(_ data: Data) throws -> CacheableModel {
        try JSONDecoder().decode(CacheableModel.self, from: data)
    }

    func decodeFailureResponseData(_ data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

