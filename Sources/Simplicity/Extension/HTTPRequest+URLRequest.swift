//
//  HTTPRequest+URLRequest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

import Foundation

extension HTTPRequest where RequestBody: Encodable & Sendable {
    /// Encodes this request as a URLRequest, using the provided base URL.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        let url = baseURL.appending(path: path).appending(queryItems: queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.httpBody = try JSONEncoder().encode(httpBody)
        return urlRequest
    }
}

extension HTTPRequest where RequestBody == Never {
    /// Encodes this request as a URLRequest, using the provided base URL.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        let url = baseURL.appending(path: path).appending(queryItems: queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        return urlRequest
    }
}

extension HTTPRequest where RequestBody == Never? {
    /// Encodes this request as a URLRequest, using the provided base URL.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        let url = baseURL.appending(path: path).appending(queryItems: queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        return urlRequest
    }
}
