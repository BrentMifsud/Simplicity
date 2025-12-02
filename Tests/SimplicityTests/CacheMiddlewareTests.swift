import Foundation
import Testing
@testable import Simplicity

@Suite("CacheMiddleware Tests")
struct CacheMiddlewareTests {
    let baseURL = URL(string: "https://example.com/api")!

    @Test
    func testReturnCacheDataElseLoad_returnsCachedResponse_whenAvailable() async throws {
        // Arrange
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let cachedData = Data("cached".utf8)
        let networkData = Data("network".utf8)

        // Pre-populate cache
        await middleware.setCached(cachedData, for: url)

        let request: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { _ in
            return (statusCode: .ok, url: url, headers: [:], httpBody: networkData)
        }

        // Act
        let response = try await middleware.intercept(request: request, next: next)

        // Assert - should return cached data, not network data
        #expect(response.httpBody == cachedData)
    }

    @Test
    func testReturnCacheDataElseLoad_callsNetwork_whenNotCached() async throws {
        // Arrange
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let networkData = Data("network".utf8)

        let request: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { _ in
            return (statusCode: .ok, url: url, headers: [:], httpBody: networkData)
        }

        // Act
        let response = try await middleware.intercept(request: request, next: next)

        // Assert - should return network data since nothing was cached
        #expect(response.httpBody == networkData)
    }

    @Test
    func testReturnCacheDataDontLoad_throwsCacheMiss_whenNotCached() async throws {
        // Arrange
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")

        let request: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataDontLoad
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { _ in
            Issue.record("Network should not be called")
            return (statusCode: .ok, url: url, headers: [:], httpBody: Data())
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
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let cachedData = Data("cached".utf8)
        let networkData = Data("network".utf8)

        await middleware.setCached(cachedData, for: url)

        let request: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataDontLoad
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { _ in
            return (statusCode: .ok, url: url, headers: [:], httpBody: networkData)
        }

        // Act
        let response = try await middleware.intercept(request: request, next: next)

        // Assert - should return cached data, not network data
        #expect(response.httpBody == cachedData)
    }

    @Test
    func testReloadIgnoringLocalCacheData_alwaysCallsNetwork() async throws {
        // Arrange
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let cachedData = Data("cached".utf8)
        let networkData = Data("network".utf8)

        // Pre-populate cache
        await middleware.setCached(cachedData, for: url)

        let request: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [],
            headers: [:],
            httpBody: nil,
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { _ in
            return (statusCode: .ok, url: url, headers: [:], httpBody: networkData)
        }

        // Act
        let response = try await middleware.intercept(request: request, next: next)

        // Assert - should return network data even though cache exists
        #expect(response.httpBody == networkData)
    }

    @Test
    func testCachesSuccessResponsesByDefault() async throws {
        // Arrange
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let networkData = Data("network".utf8)

        let request: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { _ in
            return (statusCode: .ok, url: url, headers: [:], httpBody: networkData)
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
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache)
        let url = baseURL.appending(path: "/test")
        let errorData = Data("error".utf8)

        let request: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { _ in
            return (statusCode: .badRequest, url: url, headers: [:], httpBody: errorData)
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
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache) { _ in true } // Cache everything
        let url = baseURL.appending(path: "/test")
        let errorData = Data("error".utf8)

        let request: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { _ in
            return (statusCode: .badRequest, url: url, headers: [:], httpBody: errorData)
        }

        // Act
        _ = try await middleware.intercept(request: request, next: next)

        // Assert - cache SHOULD have the error response with custom predicate
        let hasCached = await middleware.hasCachedResponse(for: url)
        #expect(hasCached)
    }

    @Test
    func testDifferentQueryParams_differentCacheEntries() async throws {
        // Arrange
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let middleware = CacheMiddleware(urlCache: cache)
        let data1 = Data("data1".utf8)
        let data2 = Data("data2".utf8)

        let request1: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [URLQueryItem(name: "filter", value: "a")],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataElseLoad
        )

        let request2: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [URLQueryItem(name: "filter", value: "b")],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataElseLoad
        )

        let next: @Sendable (Middleware.Request) async throws -> Middleware.Response = { req in
            let url = req.baseURL.appending(path: req.path).appending(queryItems: req.queryItems)
            let data = req.queryItems.first?.value == "a" ? data1 : data2
            return (statusCode: .ok, url: url, headers: [:], httpBody: data)
        }

        // Act - make both requests (will call network and cache)
        let response1 = try await middleware.intercept(request: request1, next: next)
        let response2 = try await middleware.intercept(request: request2, next: next)

        // Assert - each request should return its own data
        #expect(response1.httpBody == data1)
        #expect(response2.httpBody == data2)

        // Verify both are now cached separately
        let url1 = baseURL.appending(path: "/test").appending(queryItems: [URLQueryItem(name: "filter", value: "a")])
        let url2 = baseURL.appending(path: "/test").appending(queryItems: [URLQueryItem(name: "filter", value: "b")])
        #expect(await middleware.hasCachedResponse(for: url1))
        #expect(await middleware.hasCachedResponse(for: url2))

        // Make requests again with returnCacheDataDontLoad to verify cache hit
        let request1Cached: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [URLQueryItem(name: "filter", value: "a")],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataDontLoad
        )
        let request2Cached: Middleware.Request = (
            operationID: "test",
            httpMethod: .get,
            baseURL: baseURL,
            path: "/test",
            queryItems: [URLQueryItem(name: "filter", value: "b")],
            headers: [:],
            httpBody: nil,
            cachePolicy: .returnCacheDataDontLoad
        )

        let cached1 = try await middleware.intercept(request: request1Cached, next: next)
        let cached2 = try await middleware.intercept(request: request2Cached, next: next)

        #expect(cached1.httpBody == data1)
        #expect(cached2.httpBody == data2)
    }

    @Test
    func testRemoveCached_invalidatesEntry() async throws {
        // Arrange
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
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
        let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
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
