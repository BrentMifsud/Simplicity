//
//  CacheMiddleware.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-12-02.
//

public import Foundation
public import HTTPTypes
import HTTPTypesFoundation
#if canImport(FoundationNetworking)
public import FoundationNetworking
#endif

/// A middleware that provides caching for HTTP responses using `URLCache`.
///
/// `CacheMiddleware` intercepts requests and responses to provide caching behavior that
/// respects the `CachePolicy` specified in each request. Unlike URLSession's built-in caching,
/// this middleware caches based on the final request URL (after all middleware modifications),
/// making it compatible with authentication headers and other request transformations.
///
/// Features:
/// - Respects `CachePolicy` from each request (e.g., `returnCacheDataElseLoad`, `reloadIgnoringLocalCacheData`)
/// - Caches responses after middleware chain completes (so auth headers are included in cache key derivation)
/// - Configurable response caching predicate (defaults to success responses only)
/// - Manual cache management via `setCached`, `removeCached`, and `clearCache`
///
/// Usage:
/// ```swift
/// let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 50_000_000)
/// let cacheMiddleware = CacheMiddleware(urlCache: cache)
///
/// let client = URLSessionClient(
///     urlSession: session,
///     baseURL: baseURL,
///     middlewares: [authMiddleware, cacheMiddleware]
/// )
/// ```
///
/// - Important: Place `CacheMiddleware` after authentication middleware so that the cache key
///   is derived from the fully-formed request URL. The cache key is based on the URL only,
///   not headers, so requests with different auth tokens but the same URL will share cache entries.
public actor CacheMiddleware: Middleware {
    /// The underlying URL cache used for storage.
    public let urlCache: URLCache

    /// A predicate that determines whether a response should be cached.
    /// Defaults to caching only successful responses (2xx status codes).
    public let shouldCacheResponse: @Sendable (MiddlewareResponse) -> Bool

    /// Creates a new cache middleware.
    ///
    /// - Parameters:
    ///   - urlCache: The `URLCache` to use for storing responses. Defaults to `.shared`.
    ///   - shouldCacheResponse: A predicate that determines whether a response should be cached.
    ///     Defaults to caching only successful responses (2xx status codes).
    public init(
        urlCache: URLCache = .shared,
        shouldCacheResponse: @escaping @Sendable (MiddlewareResponse) -> Bool = { $0.httpResponse.status.kind == .successful }
    ) {
        self.urlCache = urlCache
        self.shouldCacheResponse = shouldCacheResponse
    }

    public func intercept(
        request: MiddlewareRequest,
        next: nonisolated(nonsending) @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse
    ) async throws -> MiddlewareResponse {
        let url = request.url
        let urlRequest = cacheKeyRequest(for: url)

        // Handle cache policy
        switch request.cachePolicy {
        case .returnCacheDataDontLoad:
            if let cached = cachedResponse(for: urlRequest) {
                return cached
            }
            throw ClientError.cacheMiss

        case .returnCacheDataElseLoad:
            if let cached = cachedResponse(for: urlRequest) {
                return cached
            }
            // Fall through to network request

        case .reloadIgnoringLocalCacheData, .reloadIgnoringLocalAndRemoteCacheData:
            break

        case .reloadRevalidatingCacheData:
            // TODO: Implement proper revalidation with If-None-Match/If-Modified-Since
            break

        case .useProtocolCachePolicy:
            if let cached = cachedResponse(for: urlRequest) {
                return cached
            }
        }

        let response = try await next(request)

        if shouldCacheResponse(response) {
            storeCachedResponse(response, for: urlRequest)
        }

        return response
    }

    // MARK: - Manual Cache Management

    /// Manually stores a response in the cache for the given URL.
    ///
    /// - Parameters:
    ///   - data: The response body data to cache.
    ///   - url: The URL to use as the cache key.
    ///   - status: The HTTP status. Defaults to `.ok`.
    ///   - headerFields: The response header fields. Defaults to empty (Content-Type: application/json is added automatically).
    public func setCached(
        _ data: Data,
        for url: URL,
        status: HTTPResponse.Status = .ok,
        headerFields: HTTPFields = HTTPFields()
    ) {
        let urlRequest = cacheKeyRequest(for: url)

        var headerDict: [String: String] = [:]
        for field in headerFields {
            headerDict[field.name.rawName] = field.value
        }
        if headerDict["Content-Type"] == nil {
            headerDict["Content-Type"] = "application/json"
        }

        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: status.code,
            httpVersion: "HTTP/1.1",
            headerFields: headerDict
        ) else { return }

        let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
        urlCache.storeCachedResponse(cachedResponse, for: urlRequest)
    }

    /// Removes the cached response for the given URL.
    ///
    /// - Parameter url: The URL whose cached response should be removed.
    public func removeCached(for url: URL) {
        let urlRequest = cacheKeyRequest(for: url)
        urlCache.removeCachedResponse(for: urlRequest)
    }

    /// Removes all cached responses.
    public func clearCache() {
        urlCache.removeAllCachedResponses()
    }

    /// Checks if a cached response exists for the given URL.
    ///
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if a cached response exists, `false` otherwise.
    public func hasCachedResponse(for url: URL) -> Bool {
        let urlRequest = cacheKeyRequest(for: url)
        return urlCache.cachedResponse(for: urlRequest) != nil
    }

    // MARK: - Private Helpers

    private func cachedResponse(for urlRequest: URLRequest) -> MiddlewareResponse? {
        guard let cached = urlCache.cachedResponse(for: urlRequest),
              let httpURLResponse = cached.response as? HTTPURLResponse,
              let httpResponse = httpURLResponse.httpResponse,
              let url = httpURLResponse.url else {
            return nil
        }

        return MiddlewareResponse(
            httpResponse: httpResponse,
            url: url,
            body: cached.data
        )
    }

    private func storeCachedResponse(_ response: MiddlewareResponse, for urlRequest: URLRequest) {
        // Convert HTTPFields to [String: String] for HTTPURLResponse construction
        var headerDict: [String: String] = [:]
        for field in response.httpResponse.headerFields {
            headerDict[field.name.rawName] = field.value
        }

        guard let httpResponse = HTTPURLResponse(
            url: response.url,
            statusCode: response.httpResponse.status.code,
            httpVersion: "HTTP/1.1",
            headerFields: headerDict
        ) else { return }

        let cachedResponse = CachedURLResponse(response: httpResponse, data: response.body)
        urlCache.storeCachedResponse(cachedResponse, for: urlRequest)
    }
}
