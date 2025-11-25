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
    associatedtype RequestBody: Encodable & Sendable = Never
    /// The type of the response body, which must be `Decodable` and `Sendable`.
    associatedtype SuccessResponseBody: Decodable & Sendable = Never
    /// The type of the response body, which must be `Decodable` and `Sendable`.
    associatedtype FailureResponseBody: Decodable & Sendable = Never

    /// A unique identifier for the operation or endpoint.
    static var operationID: String { get }
    /// The path component of the HTTP request URL (relative to the base URL).
    var path: String { get }
    /// The HTTP method (e.g., GET, POST, PUT, DELETE) for this request.
    var httpMethod: HTTPMethod { get }
    /// Additional HTTP headers to include in the request.
    var headers: [String: String] { get }
    /// The URL query items to include in the request URL.
    var queryItems: [URLQueryItem] { get }
    /// The body of the HTTP request, typed as `RequestBody`.
    var httpBody: RequestBody { get }

    /// Encodes this request’s body into `Data` for transmission over HTTP.
    ///
    /// The default implementation (provided in `HTTPRequest+URLRequest.swift`) behaves as follows:
    /// - If `RequestBody` is `Never` or `Never?`, this method returns `nil`, indicating that the
    ///   request has no body.
    /// - Otherwise, it encodes `httpBody` using `JSONEncoder` and returns the resulting `Data`.
    ///
    /// Conforming types may override this method to implement alternative encodings, such as:
    /// - `application/x-www-form-urlencoded`
    /// - `multipart/form-data`
    /// - Binary payloads (e.g., images, files)
    /// - Custom serialization formats
    ///
    /// Important:
    /// - This method does not set any HTTP headers. If you change the encoding, ensure you supply an
    ///   appropriate `Content-Type` (and related headers like `Content-Length` when applicable) via
    ///   your `headers` or within your `createURLRequest(baseURL:)` implementation.
    /// - Downstream middleware and the HTTP client may further transform or replace the body before
    ///   sending the request.
    ///
    /// - Returns: The encoded body as `Data`, or `nil` if the request has no body.
    /// - Throws: Any error thrown by the chosen encoder while encoding `httpBody`.
    /// - SeeAlso: `createURLRequest(baseURL:)`, `headers`
    func encodeHTTPBody() throws -> Data?

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
    func createURLRequest(baseURL: URL) -> URLRequest

    /// Decodes the HTTP response data into this request's `ResponseBody` type.
    ///
    /// - Parameter data: The raw data returned by the HTTP response.
    /// - Returns: The decoded `ResponseBody` object.
    /// - Throws: An error if decoding the response data fails.
    func decodeSuccessResponseData(_ data: Data) throws -> SuccessResponseBody

    /// Decodes the HTTP response data into this request's `SuccessResponseBody` type.
    ///
    /// - Parameter data: The raw data returned by the HTTP response.
    /// - Returns: The decoded `FailureResponseBody` object.
    /// - Throws: An error if decoding the response data fails.
    func decodeFailureResponseData(_ data: Data) throws -> FailureResponseBody
}

// MARK: Default implementation

public extension HTTPRequest {
    /// Builds the absolute URL by appending this request's `path` and `queryItems` to `baseURL`.
    ///
    /// - Parameter baseURL: The base URL to which the request-specific `path` and `queryItems` are applied.
    /// - Returns: A `URL` representing the full endpoint for this request.
    func requestURL(baseURL: URL) -> URL {
        let url = baseURL.appending(path: path)

        guard !queryItems.isEmpty else {
            return url
        }

        return url.appending(queryItems: queryItems)
    }
}

public extension HTTPRequest where RequestBody == Never {
    var httpBody: Never {
        get { fatalError("\(type(of: self)) does not have a request body") }
        set {}
    }
}

public extension HTTPRequest where RequestBody == Never? {
    var httpBody: Never? {
        get { nil }
        set { fatalError("\(type(of: self)) does not have a request body") }
    }
}

public extension HTTPRequest where SuccessResponseBody: Decodable {
    /// Default implementation of `decodeSuccessResponseData(_:)`.
    /// This method decodes the response data from JSON into the `SuccessResponseBody` type.
    /// Conformers can override this method for custom decoding behavior.
    func decodeSuccessResponseData(_ data: Data) throws -> SuccessResponseBody {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601Long
        return try decoder.decode(SuccessResponseBody.self, from: data)
    }
}

public extension HTTPRequest where FailureResponseBody: Decodable {
    /// Default implementation of `decodeFailureResponseData(_:)`.
    /// This method decodes the response data from JSON into the `FailureResponseBody` type.
    /// Conformers can override this method for custom decoding behavior.
    func decodeFailureResponseData(_ data: Data) throws -> FailureResponseBody {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601Long
        return try decoder.decode(FailureResponseBody.self, from: data)
    }
}
