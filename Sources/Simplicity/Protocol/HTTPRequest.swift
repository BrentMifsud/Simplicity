//
//  HTTPRequest.swift
//  Noms
//
//  Created by Brent Mifsud on 2025-08-06.
//

public import Foundation

/// Defines a type that represents a type-safe HTTP request, including its request and response types, metadata, and encoding/decoding logic.
///
/// Example:
/// ```swift
/// struct GetProfileRequest: HTTPRequest {
///     struct ResponseBody: Decodable, Sendable {
///         let id: Int
///         let username: String
///     }
///
///     static let operationID = "getProfile"
///     let path = "/user/profile"
///     let httpMethod: HTTPMethod = .get
///     let headers: [String: String] = [:]
///     let queryItems: [URLQueryItem] = []
///     let httpBody: Never?
/// }
/// ```
public nonisolated protocol HTTPRequest: Sendable {
    /// The type of the request body, which must be `Encodable` and `Sendable`.
    associatedtype RequestBody: Encodable & Sendable
    /// The type of the response body, which must be `Decodable` and `Sendable`.
    associatedtype ResponseBody: Decodable & Sendable
    
    /// A unique identifier for the operation or endpoint.
    static var operationID: String { get }
    /// The path component of the HTTP request URL (relative to the base URL).
    var path: String { get }
    /// The HTTP method (e.g., GET, POST, PUT, DELETE) for this request.
    var httpMethod: HTTPMethod { get }
    /// Additional HTTP headers to include in the request.
    var headers: [String: String] { get set }
    /// The URL query items to include in the request URL.
    var queryItems: [URLQueryItem] { get set }
    /// The body of the HTTP request, typed as `RequestBody`.
    var httpBody: RequestBody { get set }

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
    func encodeURLRequest(baseURL: URL) throws -> URLRequest

    /// Decodes the HTTP response data into this request's `ResponseBody` type.
    ///
    /// - Parameter data: The raw data returned by the HTTP response.
    /// - Returns: The decoded `ResponseBody` object.
    /// - Throws: An error if decoding the response data fails.
    func decodeResponseData(_ data: Data) throws -> ResponseBody
}

// MARK: Default implementation

public extension HTTPRequest where ResponseBody: Decodable {
    /// Default implementation of `decodeResponseData(_:)`.
    /// This method decodes the response data from JSON into the `ResponseBody` type.
    /// Conformers can override this method for custom decoding behavior.
    func decodeResponseData(_ data: Data) throws -> ResponseBody {
        let decoder = JSONDecoder()
        return try decoder.decode(ResponseBody.self, from: data)
    }
}
