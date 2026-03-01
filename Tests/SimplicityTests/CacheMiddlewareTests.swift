import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import HTTPTypes
@testable import Simplicity

@Suite("CacheMiddleware Tests")
struct CacheMiddlewareTests {
    let baseURL = URL(string: "https://example.com/api")!

    @Test
    func testReturnCacheDataElseLoad_returnsCachedResponse_whenAvailable() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let cachedData = Data("cached".utf8)
        let networkData = Data("network".utf8)

        // Pre-populate cache
        await middleware.setCached(cachedData, for: url)

        let request = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { _ in
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .ok),
                url: url,
                body: networkData
            )
        }

        // Act
        let response = try await middleware.intercept(request: request, next: next)

        // Assert - should return cached data, not network data
        #expect(response.body == cachedData)
    }

    @Test
    func testReturnCacheDataElseLoad_callsNetwork_whenNotCached() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let networkData = Data("network".utf8)

        let request = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { _ in
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .ok),
                url: url,
                body: networkData
            )
        }

        // Act
        let response = try await middleware.intercept(request: request, next: next)

        // Assert - should return network data since nothing was cached
        #expect(response.body == networkData)
    }

    @Test
    func testReturnCacheDataDontLoad_throwsCacheMiss_whenNotCached() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")

        let request = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            cachePolicy: .returnCacheDataDontLoad
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { _ in
            Issue.record("Network should not be called")
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .ok),
                url: url,
                body: Data()
            )
        }

        // Act & Assert
        do {
            _ = try await middleware.intercept(request: request, next: next)
            Issue.record("Expected cacheMiss error")
        } catch let error as ClientError {
            guard case .cacheMiss = error else {
                Issue.record("Expected cacheMiss, got: \(error)")
                return
            }
        }
    }

    @Test
    func testReturnCacheDataDontLoad_returnsCached_whenAvailable() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let cachedData = Data("cached".utf8)
        let networkData = Data("network".utf8)

        await middleware.setCached(cachedData, for: url)

        let request = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            cachePolicy: .returnCacheDataDontLoad
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { _ in
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .ok),
                url: url,
                body: networkData
            )
        }

        // Act
        let response = try await middleware.intercept(request: request, next: next)

        // Assert - should return cached data, not network data
        #expect(response.body == cachedData)
    }

    @Test
    func testReloadIgnoringLocalCacheData_alwaysCallsNetwork() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let cachedData = Data("cached".utf8)
        let networkData = Data("network".utf8)

        // Pre-populate cache
        await middleware.setCached(cachedData, for: url)

        let request = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { _ in
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .ok),
                url: url,
                body: networkData
            )
        }

        // Act
        let response = try await middleware.intercept(request: request, next: next)

        // Assert - should return network data even though cache exists
        #expect(response.body == networkData)
    }

    @Test
    func testCachesSuccessResponsesByDefault() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let networkData = Data("network".utf8)

        let request = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { _ in
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .ok),
                url: url,
                body: networkData
            )
        }

        // Act - first request should hit network and cache
        _ = try await middleware.intercept(request: request, next: next)

        // Assert - cache should now have the response
        let hasCached = await middleware.hasCachedResponse(for: url)
        #expect(hasCached)
    }

    @Test
    func testDoesNotCacheFailureResponsesByDefault() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let errorData = Data("error".utf8)

        let request = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { _ in
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .badRequest),
                url: url,
                body: errorData
            )
        }

        // Act
        _ = try await middleware.intercept(request: request, next: next)

        // Assert - cache should NOT have the error response
        let hasCached = await middleware.hasCachedResponse(for: url)
        #expect(!hasCached)
    }

    @Test
    func testCustomShouldCacheResponse_allowsCachingFailures() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache) { _ in true } // Cache everything
        let url = baseURL.appending(path: "/test")
        let errorData = Data("error".utf8)

        let request = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { _ in
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .badRequest),
                url: url,
                body: errorData
            )
        }

        // Act
        _ = try await middleware.intercept(request: request, next: next)

        // Assert - cache SHOULD have the error response with custom predicate
        let hasCached = await middleware.hasCachedResponse(for: url)
        #expect(hasCached)
    }

    // URLCache in swift-corelibs-foundation does not differentiate cache entries by query parameters.
    #if !canImport(FoundationNetworking)
    @Test
    func testDifferentQueryParams_differentCacheEntries() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let data1 = Data("data1".utf8)
        let data2 = Data("data2".utf8)

        let request1 = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            queryItems: [URLQueryItem(name: "filter", value: "a")],
            cachePolicy: .returnCacheDataElseLoad
        )

        let request2 = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            queryItems: [URLQueryItem(name: "filter", value: "b")],
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse = { req in
            let url = req.url
            // Determine which data to return based on query
            let isFilterA = url.absoluteString.contains("filter=a")
            return MiddlewareResponse(
                httpResponse: HTTPResponse(status: .ok),
                url: url,
                body: isFilterA ? data1 : data2
            )
        }

        // Act - make both requests (will call network and cache)
        let response1 = try await middleware.intercept(request: request1, next: next)
        let response2 = try await middleware.intercept(request: request2, next: next)

        // Assert - each request should return its own data
        #expect(response1.body == data1)
        #expect(response2.body == data2)

        // Verify both are now cached separately
        let url1 = makeURL(base: baseURL, path: "/test", queryItems: [URLQueryItem(name: "filter", value: "a")])
        let url2 = makeURL(base: baseURL, path: "/test", queryItems: [URLQueryItem(name: "filter", value: "b")])
        #expect(await middleware.hasCachedResponse(for: url1))
        #expect(await middleware.hasCachedResponse(for: url2))

        // Make requests again with returnCacheDataDontLoad to verify cache hit
        let request1Cached = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            queryItems: [URLQueryItem(name: "filter", value: "a")],
            cachePolicy: .returnCacheDataDontLoad
        )
        let request2Cached = makeMiddlewareRequest(
            baseURL: baseURL,
            path: "/test",
            queryItems: [URLQueryItem(name: "filter", value: "b")],
            cachePolicy: .returnCacheDataDontLoad
        )

        let cached1 = try await middleware.intercept(request: request1Cached, next: next)
        let cached2 = try await middleware.intercept(request: request2Cached, next: next)

        #expect(cached1.body == data1)
        #expect(cached2.body == data2)
    }
    #endif

    @Test
    func testRemoveCached_invalidatesEntry() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let cachedData = Data("cached".utf8)

        await middleware.setCached(cachedData, for: url)
        #expect(await middleware.hasCachedResponse(for: url))

        // Act
        await middleware.removeCached(for: url)

        // Assert
        #expect(!(await middleware.hasCachedResponse(for: url)))
    }

    @Test
    func testClearCache_removesAllEntries() async throws {
        // Arrange
        let cache = makeTestCache()
        let middleware = CacheMiddleware(urlCache: cache)
        let url1 = baseURL.appending(path: "/test1")
        let url2 = baseURL.appending(path: "/test2")

        await middleware.setCached(Data("1".utf8), for: url1)
        await middleware.setCached(Data("2".utf8), for: url2)

        #expect(await middleware.hasCachedResponse(for: url1))
        #expect(await middleware.hasCachedResponse(for: url2))

        // Act
        await middleware.clearCache()

        // Assert
        #expect(!(await middleware.hasCachedResponse(for: url1)))
        #expect(!(await middleware.hasCachedResponse(for: url2)))
    }
}

// MARK: - Test Helpers

private func makeTestCache() -> URLCache {
    #if canImport(FoundationNetworking)
    URLCache(memoryCapacity: 10_000_000, diskCapacity: 0, diskPath: nil)
    #else
    URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
    #endif
}

/// Constructs a `MiddlewareRequest` for testing purposes.
private func makeMiddlewareRequest(
    baseURL: URL,
    path: String,
    queryItems: [URLQueryItem] = [],
    cachePolicy: CachePolicy
) -> MiddlewareRequest {
    let url = makeURL(base: baseURL, path: path, queryItems: queryItems)
    let httpRequest = HTTPRequest(method: .get, url: url, headerFields: HTTPFields())
    return MiddlewareRequest(
        httpRequest: httpRequest,
        body: nil,
        operationID: "test",
        baseURL: baseURL,
        cachePolicy: cachePolicy
    )
}

private func makeURL(base: URL, path: String, queryItems: [URLQueryItem] = []) -> URL {
    let url = base.appending(path: path)
    guard !queryItems.isEmpty else { return url }
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    components.queryItems = queryItems
    return components.url!
}
