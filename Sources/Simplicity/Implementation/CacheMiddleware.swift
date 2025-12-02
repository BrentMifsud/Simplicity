//
//  CacheMiddleware.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-12-02.
//

public import Foundation

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
/// let client = URLSessionHTTPClient(
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
    public let shouldCacheResponse: @Sendable (Middleware.Response) -> Bool

    /// Creates a new cache middleware.
    ///
    /// - Parameters:
    ///   - urlCache: The `URLCache` to use for storing responses. Defaults to `.shared`.
    ///   - shouldCacheResponse: A predicate that determines whether a response should be cached.
    ///     Defaults to caching only successful responses (2xx status codes).
    public init(
        urlCache: URLCache = .shared,
        shouldCacheResponse: @escaping @Sendable (Middleware.Response) -> Bool = { $0.statusCode.isSuccess }
    ) {
        self.urlCache = urlCache
        self.shouldCacheResponse = shouldCacheResponse
    }

    public func intercept(
        request: Middleware.Request,
        next: nonisolated(nonsending) @Sendable (Middleware.Request) async throws -> Middleware.Response
    ) async throws -> Middleware.Response {
        let url = requestURL(request: request)
        let urlRequest = URLRequest(url: url)

        // Handle cache policy
        switch request.cachePolicy {
        case .returnCacheDataDontLoad:
            // Only return cached data, never load from network
            if let cached = cachedResponse(for: urlRequest) {
                return cached
            }
            throw ClientError.cacheMiss

        case .returnCacheDataElseLoad:
            // Return cached data if available, otherwise load from network
            if let cached = cachedResponse(for: urlRequest) {
                return cached
            }
            // Fall through to network request

        case .reloadIgnoringLocalCacheData, .reloadIgnoringLocalAndRemoteCacheData:
            // Ignore cache, always load from network (but still cache the response)
            break

        case .reloadRevalidatingCacheData:
            // TODO: Implement proper revalidation with If-None-Match/If-Modified-Since
            // For now, treat as reload
            break

        case .useProtocolCachePolicy:
            // Check cache first, similar to returnCacheDataElseLoad
            // In a full implementation, this would respect HTTP cache headers
            if let cached = cachedResponse(for: urlRequest) {
                return cached
            }
        }

        // Make the network request
        let response = try await next(request)

        // Cache the response if appropriate
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
    ///   - statusCode: The HTTP status code. Defaults to `.ok`.
    ///   - headers: The response headers. Defaults to JSON content type.
    public func setCached(
        _ data: Data,
        for url: URL,
        statusCode: HTTPStatusCode = .ok,
        headers: [String: String] = ["Content-Type": "application/json"]
    ) {
        let urlRequest = URLRequest(url: url)
        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode.rawValue,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else { return }

        let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
        urlCache.storeCachedResponse(cachedResponse, for: urlRequest)
    }

    /// Removes the cached response for the given URL.
    ///
    /// - Parameter url: The URL whose cached response should be removed.
    public func removeCached(for url: URL) {
        let urlRequest = URLRequest(url: url)
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
        let urlRequest = URLRequest(url: url)
        return urlCache.cachedResponse(for: urlRequest) != nil
    }

    // MARK: - Private Helpers

    private func cachedResponse(for urlRequest: URLRequest) -> Middleware.Response? {
        guard let cached = urlCache.cachedResponse(for: urlRequest),
              let httpResponse = cached.response as? HTTPURLResponse,
              let statusCode = HTTPStatusCode(rawValue: httpResponse.statusCode),
              let url = httpResponse.url else {
            return nil
        }

        let headers: [String: String] = httpResponse.allHeaderFields.reduce(into: [:]) { dict, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                dict[key] = value
            }
        }

        return (statusCode: statusCode, url: url, headers: headers, httpBody: cached.data)
    }

    private func storeCachedResponse(_ response: Middleware.Response, for urlRequest: URLRequest) {
        guard let httpResponse = HTTPURLResponse(
            url: response.url,
            statusCode: response.statusCode.rawValue,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        ) else { return }

        let cachedResponse = CachedURLResponse(response: httpResponse, data: response.httpBody)
        urlCache.storeCachedResponse(cachedResponse, for: urlRequest)
    }
}
