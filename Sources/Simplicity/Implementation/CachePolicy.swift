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

/// Uses the caching behavior defined by the protocol implementation and server-provided
/// cache directives (e.g., Cache-Control, ETag, Expires).
///
/// This is the default and generally recommended option. The system will consult the
/// cache and follow HTTP caching semantics to determine whether to return cached data,
/// revalidate it, or fetch anew.

/// Ignores any locally cached data and fetches the resource from the network.
/// The response may still be stored in the cache, depending on cache configuration.
///
/// Use this when you need the freshest data and can afford a network round trip.
/// This does not bypass remote caches/proxies that might still serve cached data.

/// Ignores both local cache and any remote/proxy caches, forcing a full end-to-end
/// fetch from the origin server where possible.
///
/// Use this when you must bypass all caching layers. Note that some intermediaries
/// may still not honor this instruction in all scenarios.

/// Returns cached data if it exists and is valid; otherwise, performs a network load.
/// This provides a good balance between performance and freshness.
///
/// Use this when you want to benefit from cached responses but still fall back to
/// the network if needed.

/// Returns cached data if it exists and is valid; otherwise, fails without attempting
/// a network load. This enforces strict offline behavior.
///
/// Use this for offline modes or when network access is not desired or permitted.

/// Asks the server to revalidate cached data (using conditional requests such as
/// If-None-Match/If-Modified-Since). If the cache is still valid, a lightweight
/// 304 Not Modified response may be returned and the cached data reused.
///
/// Use this when you want to ensure freshness while minimizing bandwidth by
/// leveraging cache validators.
public nonisolated enum CachePolicy: Sendable {
    case useProtocolCachePolicy
    case reloadIgnoringLocalCacheData
    case reloadIgnoringLocalAndRemoteCacheData
    case returnCacheDataElseLoad
    case returnCacheDataDontLoad
    case reloadRevalidatingCacheData
}
