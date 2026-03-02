//
//  URLCacheCompat.swift
//  Simplicity
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Creates a `URLRequest` to use as a `URLCache` key for the given URL.
///
/// On Linux, `URLCache` in swift-corelibs-foundation does not differentiate cache entries
/// by URL query parameters. This function works around the limitation by encoding the full
/// URL (including query string) into a synthetic path component, ensuring unique cache keys.
///
/// On Apple platforms, this simply returns `URLRequest(url:)`.
func cacheKeyRequest(for url: URL) -> URLRequest {
    #if canImport(FoundationNetworking)
    // Encode the entire URL (scheme, host, path, query, fragment) into a single
    // percent-encoded path segment. The resulting synthetic URL has no query component,
    // so URLCache cannot collapse entries that differ only by query parameters.
    let encoded = url.absoluteString.addingPercentEncoding(
        withAllowedCharacters: .alphanumerics
    ) ?? url.absoluteString
    return URLRequest(url: URL(string: "simplicity-cache://entry/\(encoded)")!)
    #else
    return URLRequest(url: url)
    #endif
}
