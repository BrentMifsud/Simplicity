import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import HTTPTypes
@testable import Simplicity

// MARK: - Tests

@Suite("URLSessionClient Tests")
struct URLSessionClientTests {
    let baseURL = URL(string: "https://example.com/api")!

    @Test
    func testSuccessDecoding_returnsModel() async throws {
        // Arrange
        let expected = SuccessModel(value: "ok")
        let client = makeClient(baseURL: baseURL) { _, _ in
            let data = try JSONEncoder().encode(expected)
            return (data, HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]))
        }

        // Act
        let response = try await client.send(GetSuccessRequest())

        // Assert
        let model = try JSONDecoder().decode(SuccessModel.self, from: response.body)
        #expect(model == expected)
    }

    @Test
    func testFailureDecoding_returnsErrorPayload() async throws {
        // Arrange
        let expected = ErrorModel(message: "bad")
        let client = makeClient(baseURL: baseURL) { _, _ in
            let data = try JSONEncoder().encode(expected)
            return (data, HTTPResponse(status: .badRequest, headerFields: [.contentType: "application/json"]))
        }

        // Act
        let response = try await client.send(GetSuccessRequest())

        // Assert
        let err = try JSONDecoder().decode(ErrorModel.self, from: response.body)
        #expect(err == expected)
    }

    @Test
    func testRequestBodyNoneWhenRequestBodyIsNever() async throws {
        // Arrange
        let client = makeClient(baseURL: baseURL) { _, body in
            #expect(body == nil)
            return (Data(), HTTPResponse(status: .ok))
        }

        // Act
        _ = try await client.send(GetSuccessRequest())
    }

    @Test
    func testBaseURLComposition_usesClientBaseURLAndPath() async throws {
        // Arrange
        let client = makeClient(baseURL: baseURL) { request, _ in
            let url = reconstructURL(from: request)
            #expect(url == "https://example.com/api/test/success")
            return (Data(), HTTPResponse(status: .ok))
        }

        // Act
        _ = try await client.send(GetSuccessRequest())
    }

    @Test
    func testSpecialization_FailureIsNever_allowsSuccessOnly() async throws {
        // Arrange
        let expected = SuccessModel(value: "ok")
        let client = makeClient(baseURL: baseURL) { _, _ in
            let data = try JSONEncoder().encode(expected)
            return (data, HTTPResponse(status: .ok))
        }

        // Act
        let response = try await client.send(SuccessOnlyRequest())
        let model = try response.decodeSuccessBody()

        // Assert
        #expect(model == expected)
    }

    @Test
    func testSpecialization_SuccessIsNever_allowsFailureOnly() async throws {
        // Arrange
        let expected = ErrorModel(message: "nope")
        let client = makeClient(baseURL: baseURL) { _, _ in
            let data = try JSONEncoder().encode(expected)
            return (data, HTTPResponse(status: .badRequest))
        }

        // Act
        let response = try await client.send(FailureOnlyRequest())
        let err = try response.decodeFailureBody()

        // Assert
        #expect(err == expected)
    }

    @Test
    func testMiddlewareNonClientError_isWrappedAsMiddlewareAndNotNested() async throws {
        // Arrange
        enum DummyError: Error, Equatable { case boom }
        let throwingMiddleware = MiddlewareSpy(thrownError: DummyError.boom)
        let client = makeClient(baseURL: baseURL, middlewares: [throwingMiddleware]) { _, _ in
            Issue.record("Handler should not be called when middleware throws")
            return (Data(), HTTPResponse(status: .ok))
        }

        // Act
        do {
            _ = try await client.send(GetSuccessRequest())
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
        let client = makeClient(baseURL: baseURL, middlewares: [middleware]) { _, _ in
            Issue.record("Handler should not be called when middleware throws")
            return (Data(), HTTPResponse(status: .ok))
        }

        // Act
        do {
            _ = try await client.send(GetSuccessRequest())
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
        let client = makeClient(baseURL: baseURL) { _, _ in
            throw URLError(.badServerResponse)
        }

        // Act
        do {
            _ = try await client.send(GetSuccessRequest())
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
    func testUnusualStatusCode_returnsResponseWithInvalidKind() async throws {
        // Arrange
        let client = makeClient(baseURL: baseURL) { _, _ in
            (Data(), HTTPResponse(status: HTTPResponse.Status(code: 999)))
        }

        // Act — with Apple's HTTPResponse.Status, any status code is valid
        let response = try await client.send(GetSuccessRequest())

        // Assert — status code 999 has kind .invalid
        #expect(response.status.code == 999)
        #expect(response.status.kind == .invalid)
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
        case .encodingError(_, let underlying):
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

private func makeClient(
    baseURL: URL,
    middlewares: [any Middleware] = [],
    handler: @escaping @Sendable (HTTPRequest, Data?) async throws -> (Data, HTTPResponse)
) -> URLSessionClient {
    URLSessionClient(
        transport: MockTransport(handler: handler),
        baseURL: baseURL,
        middlewares: middlewares
    )
}

/// Reconstructs a URL string from an HTTPRequest's components for test assertions.
private func reconstructURL(from request: HTTPRequest) -> String {
    var string = ""
    if let scheme = request.scheme {
        string += scheme + "://"
    }
    if let authority = request.authority {
        string += authority
    }
    if let path = request.path {
        string += path
    }
    return string
}

// MARK: - Test Requests

private struct SuccessModel: Codable, Sendable, Equatable { let value: String }
private struct ErrorModel: Codable, Sendable, Equatable { let message: String }

private struct GetSuccessRequest: Request {
    typealias RequestBody = Never
    typealias SuccessResponseBody = SuccessModel
    typealias FailureResponseBody = ErrorModel

    static var operationID: String { "success" }
    var method: HTTPRequest.Method { .get }
    var path: String { "/test/success" }
    var headerFields: HTTPFields { HTTPFields() }
    var queryItems: [URLQueryItem] { [] }

    func decodeSuccessBody(from data: Data) throws -> SuccessModel {
        try JSONDecoder().decode(SuccessModel.self, from: data)
    }

    func decodeFailureBody(from data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

private struct PostWithBodyRequest: Request {
    typealias RequestBody = SuccessModel
    typealias SuccessResponseBody = SuccessModel
    typealias FailureResponseBody = ErrorModel

    static var operationID: String { "body" }
    var method: HTTPRequest.Method { .post }
    var path: String { "/test/body" }
    var headerFields: HTTPFields { [.contentType: "application/json"] }
    var queryItems: [URLQueryItem] { [] }
    var body: SuccessModel

    func encodeBody() throws -> Data? {
        try JSONEncoder().encode(body)
    }

    func decodeSuccessBody(from data: Data) throws -> SuccessModel {
        try JSONDecoder().decode(SuccessModel.self, from: data)
    }

    func decodeFailureBody(from data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

private struct FailureOnlyRequest: Request {
    typealias RequestBody = Never
    typealias SuccessResponseBody = Never
    typealias FailureResponseBody = ErrorModel

    static var operationID: String { "failure" }
    var method: HTTPRequest.Method { .get }
    var path: String { "/test/failure-only" }
    var headerFields: HTTPFields { HTTPFields() }
    var queryItems: [URLQueryItem] { [] }

    func encodeBody() throws -> Data? { nil }

    func decodeSuccessBody(from data: Data) throws -> Never {
        fatalError("should not decode success for FailureOnlyRequest")
    }

    func decodeFailureBody(from data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

private struct SuccessOnlyRequest: Request {
    typealias RequestBody = Never
    typealias SuccessResponseBody = SuccessModel
    typealias FailureResponseBody = Never

    static var operationID: String { "success-only" }
    var method: HTTPRequest.Method { .get }
    var path: String { "/test/success-only" }
    var headerFields: HTTPFields { HTTPFields() }
    var queryItems: [URLQueryItem] { [] }

    func encodeBody() throws -> Data? { nil }

    func decodeSuccessBody(from data: Data) throws -> SuccessModel {
        try JSONDecoder().decode(SuccessModel.self, from: data)
    }

    func decodeFailureBody(from data: Data) throws -> Never {
        fatalError("should not decode failure for SuccessOnlyRequest")
    }
}

// MARK: - Decoding Error Tests

@Suite("Response Decoding Error Tests")
struct ResponseDecodingErrorTests {
    @Test
    func testDecodeSuccessBody_throwsDecodingError_withResponseBody() throws {
        // Arrange — response body is valid JSON but wrong shape for SuccessModel
        let mismatchedBody = Data("{\"unexpected\":\"field\"}".utf8)
        let response = Response<SuccessModel, ErrorModel>(
            httpResponse: HTTPResponse(status: .ok),
            url: URL(string: "https://example.com/test")!,
            body: mismatchedBody,
            successBodyDecoder: { data in
                try JSONDecoder().decode(SuccessModel.self, from: data)
            },
            failureBodyDecoder: { data in
                try JSONDecoder().decode(ErrorModel.self, from: data)
            }
        )

        // Act & Assert
        do {
            _ = try response.decodeSuccessBody()
            Issue.record("Expected decodingError to be thrown")
        } catch let error as ClientError {
            guard case let .decodingError(type, responseBody, underlyingError) = error else {
                Issue.record("Expected ClientError.decodingError, got: \(error)")
                return
            }
            #expect(type == "SuccessModel")
            #expect(responseBody == mismatchedBody)
            #expect(underlyingError is DecodingError)
        }
    }

    @Test
    func testDecodeFailureBody_throwsDecodingError_withResponseBody() throws {
        // Arrange — response body is not valid JSON at all
        let invalidBody = Data("not json".utf8)
        let response = Response<SuccessModel, ErrorModel>(
            httpResponse: HTTPResponse(status: .badRequest),
            url: URL(string: "https://example.com/test")!,
            body: invalidBody,
            successBodyDecoder: { data in
                try JSONDecoder().decode(SuccessModel.self, from: data)
            },
            failureBodyDecoder: { data in
                try JSONDecoder().decode(ErrorModel.self, from: data)
            }
        )

        // Act & Assert
        do {
            _ = try response.decodeFailureBody()
            Issue.record("Expected decodingError to be thrown")
        } catch let error as ClientError {
            guard case let .decodingError(type, responseBody, underlyingError) = error else {
                Issue.record("Expected ClientError.decodingError, got: \(error)")
                return
            }
            #expect(type == "ErrorModel")
            #expect(responseBody == invalidBody)
            #expect(underlyingError is DecodingError)
        }
    }

    @Test
    func testDecodingError_errorDescription_includesResponseBody() throws {
        let body = Data("{\"wrong\":true}".utf8)
        let error = ClientError.decodingError(
            type: "SuccessModel",
            responseBody: body,
            underlyingError: DecodingError.keyNotFound(
                AnyCodingKey(stringValue: "value"),
                .init(codingPath: [], debugDescription: "No value for key 'value'")
            )
        )

        let description = error.errorDescription ?? ""
        #expect(description.contains("Failed to decode SuccessModel"))
        #expect(description.contains("{\"wrong\":true}"))
    }
}

/// A type-erased CodingKey for test assertions.
private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
}

// MARK: - Cache Tests

@Suite("URLSessionClient Cache Tests")
struct URLSessionClientCacheTests {
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
        try await client.setCachedResponse(model, for: CacheableRequest(), status: .created)
        let cached = try await client.cachedResponse(for: CacheableRequest())

        // Assert
        #expect(cached.status == .created)
    }

    @Test
    func testCachedResponse_preservesHeaders() async throws {
        // Arrange
        let client = makeCacheableClient(baseURL: baseURL)
        let model = CacheableModel(id: 4, name: "with-headers")
        var headerFields = HTTPFields()
        headerFields[.contentType] = "application/json"
        headerFields[HTTPField.Name("X-Custom")!] = "value"

        // Act
        try await client.setCachedResponse(model, for: CacheableRequest(), headerFields: headerFields)
        let cached = try await client.cachedResponse(for: CacheableRequest())

        // Assert
        #expect(cached.headerFields[HTTPField.Name("X-Custom")!] == "value")
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

private func makeCacheableClient(baseURL: URL) -> URLSessionClient {
    #if canImport(FoundationNetworking)
    let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0, diskPath: nil)
    #else
    let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
    #endif
    return URLSessionClient(
        urlCache: cache,
        baseURL: baseURL,
        middlewares: []
    )
}

private struct CacheableModel: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

private struct CacheableRequest: Request {
    typealias RequestBody = Never
    typealias SuccessResponseBody = CacheableModel
    typealias FailureResponseBody = ErrorModel

    static var operationID: String { "cacheable" }
    var method: HTTPRequest.Method { .get }
    var path: String { "/test/cacheable" }
    var headerFields: HTTPFields { HTTPFields() }
    var queryItems: [URLQueryItem] { [] }

    func decodeSuccessBody(from data: Data) throws -> CacheableModel {
        try JSONDecoder().decode(CacheableModel.self, from: data)
    }

    func decodeFailureBody(from data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}

private struct CacheableRequestWithQuery: Request {
    typealias RequestBody = Never
    typealias SuccessResponseBody = CacheableModel
    typealias FailureResponseBody = ErrorModel

    let filter: String

    static var operationID: String { "cacheable-query" }
    var method: HTTPRequest.Method { .get }
    var path: String { "/test/cacheable" }
    var headerFields: HTTPFields { HTTPFields() }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "filter", value: filter)] }

    func decodeSuccessBody(from data: Data) throws -> CacheableModel {
        try JSONDecoder().decode(CacheableModel.self, from: data)
    }

    func decodeFailureBody(from data: Data) throws -> ErrorModel {
        try JSONDecoder().decode(ErrorModel.self, from: data)
    }
}
