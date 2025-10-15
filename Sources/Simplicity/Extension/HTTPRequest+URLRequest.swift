//
//  HTTPRequest+URLRequest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation

public extension HTTPRequest {
    /// Encodes this request into a `URLRequest` using JSON encoding by default.
    ///
    /// Conforming types may override this method to provide alternate encoding strategies
    /// (e.g., `application/x-www-form-urlencoded`, multipart, or custom formats), or to apply
    /// additional per-request configuration.
    ///
    /// For convenience, default helpers are provided:
    /// - `jsonEncodedURLRequest(baseURL:)` — builds a request with a JSON-encoded body and sets
    ///   a `Content-Type: application/json` header when not already present.
    /// - `formEncodedURLRequest(baseURL:)` — builds a request with an
    ///   `application/x-www-form-urlencoded` body and sets the corresponding content type when
    ///   not already present.
    ///
    /// You can call either helper from your override to opt into the desired encoding without
    /// reimplementing common setup.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed `URLRequest` ready for sending.
    /// - Throws: An error if encoding the request fails.
    func encodeURLRequest(baseURL: URL) throws -> URLRequest {
        try jsonEncodedURLRequest(baseURL: baseURL)
    }
}

public extension HTTPRequest {
    private func constructURL(from baseURL: URL) -> URL {
        var url = baseURL.appending(path: path)

        if !queryItems.isEmpty {
            url = url.appending(queryItems: queryItems)
        }

        return url
    }
}

public extension HTTPRequest where RequestBody: Encodable & Sendable {
    /// Encodes this request as a URLRequest, using the provided base URL.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func jsonEncodedURLRequest(baseURL: URL) throws -> URLRequest {
        let url = constructURL(from: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.httpBody = try JSONEncoder().encode(httpBody)
        // Ensure the correct Content-Type header is set if not already provided.
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        // Ensure we always accept JSON responses by default.
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        return urlRequest
    }
    
    /// Encodes this request as a URLRequest with an application/x-www-form-urlencoded body.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func formEncodedURLRequest(baseURL: URL) throws -> URLRequest {
        let url = constructURL(from: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.httpBody = try URLFormEncoder().encode(httpBody)
        // Ensure the correct Content-Type header is set if not already provided.
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        // Ensure we always accept JSON responses by default.
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        return urlRequest
    }
}

public extension HTTPRequest where RequestBody == Never {
    /// Encodes this request as a URLRequest, using the provided base URL.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func jsonEncodedURLRequest(baseURL: URL) throws -> URLRequest {
        let url = constructURL(from: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        // Ensure we always accept JSON responses by default.
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        return urlRequest
    }
    
    /// Encodes this request as a URLRequest suitable for form submissions without a body.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func formEncodedURLRequest(baseURL: URL) throws -> URLRequest {
        let url = constructURL(from: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        // Ensure we always accept JSON responses by default.
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        return urlRequest
    }
}

public extension HTTPRequest where RequestBody == Never? {
    /// Encodes this request as a URLRequest, using the provided base URL.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func jsonEncodedURLRequest(baseURL: URL) throws -> URLRequest {
        let url = constructURL(from: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        // Ensure we always accept JSON responses by default.
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        return urlRequest
    }
    
    /// Encodes this request as a URLRequest suitable for form submissions without a body.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed URLRequest ready for sending.
    /// - Throws: An error if encoding the request fails.
    func formEncodedURLRequest(baseURL: URL) throws -> URLRequest {
        let url = constructURL(from: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = headers
        urlRequest.httpMethod = httpMethod.rawValue
        // Ensure we always accept JSON responses by default.
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        return urlRequest
    }
}
