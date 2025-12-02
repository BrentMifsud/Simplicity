//
//  CachePolicy.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

/// A policy that controls how cached responses are used when performing network requests.
///
/// This type intentionally decouples cache policy from `URLRequest` so that consumers of
/// this package's `HTTPClient` API can plug in alternative transport layers (for example,
/// `URLSession/URLRequest`, SwiftNIO-based clients, or fully custom engines) without taking
/// a dependency on Foundation networking types.
///
/// `CachePolicy` mirrors the semantics of `URLRequest.CachePolicy`, providing a familiar
/// set of options while remaining transport-agnostic. Choose a policy based on whether you
/// prefer freshness (more network usage), performance (more cache usage), or strict offline
/// behavior.
///
/// Notes:
/// - These policies influence whether a cached response may be returned, whether a network
///   fetch is allowed, and whether cache revalidation headers are used.
/// - Actual behavior also depends on cache configuration (capacity, expiration, response
///   headers) and server-provided caching directives.
/// - When in doubt, prefer `.useProtocolCachePolicy` to respect server guidance.
///
/// Concurrency:
/// - Thread-safety: This type is `Sendable`.
/// - Isolation: Declared `nonisolated` and can be used freely across concurrency domains.
public nonisolated enum CachePolicy: Sendable {
    /// Uses the caching behavior defined by the protocol implementation and server-provided
    /// cache directives (for example, Cache-Control, ETag, and Expires headers).
    ///
    /// This is the default behavior. The system consults local caches and follows HTTP
    /// semantics to determine whether to return cached data, revalidate it, or fetch
    /// from the network.
    case useProtocolCachePolicy

    /// Ignores any locally cached data and fetches the resource from the network.
    /// The response may still be stored in the cache depending on configuration and
    /// response headers.
    ///
    /// Use this when you need the freshest data and can afford a full network round trip.
    /// This does not bypass remote proxies that might still serve cached responses.
    case reloadIgnoringLocalCacheData

    /// Ignores both local caches and attempts to bypass remote/proxy caches, forcing
    /// an end-to-end fetch from the origin server where possible.
    ///
    /// Use this to avoid all caching layers. Note that some intermediaries may not
    /// fully honor this behavior in all scenarios.
    case reloadIgnoringLocalAndRemoteCacheData

    /// Returns cached data if it exists and is valid; otherwise performs a network load.
    ///
    /// This provides a balance between performance and freshness by preferring cache
    /// hits but falling back to a network request when needed.
    case returnCacheDataElseLoad

    /// Returns cached data if it exists and is valid; otherwise fails without attempting
    /// a network load.
    ///
    /// Use this for strict offline modes or when network access is not desired or permitted.
    case returnCacheDataDontLoad

    /// Revalidates cached data with the server using conditional requests (for example,
    /// If-None-Match or If-Modified-Since). If the server indicates the cached response
    /// is still valid, a 304 Not Modified result allows reuse of the cached data.
    ///
    /// Use this to ensure freshness while minimizing bandwidth by leveraging cache validators.
    case reloadRevalidatingCacheData
}
