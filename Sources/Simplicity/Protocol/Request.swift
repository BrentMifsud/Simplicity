//
//  Request.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-08-06.
//

public import Foundation
public import HTTPTypes

/// Defines a type that represents a type-safe HTTP request, including its request and response types, metadata, and encoding/decoding logic.
///
/// Example:
/// ```swift
/// struct GetProfileRequest: Request {
///     struct SuccessResponseBody: Decodable, Sendable {
///         let id: Int
///         let username: String
///     }
///
///     static let operationID = "getProfile"
///     let path = "/user/profile"
///     let method: HTTPRequest.Method = .get
///     let headerFields = HTTPFields()
///     let queryItems: [URLQueryItem] = []
///     let body: Never?
/// }
/// ```
public nonisolated protocol Request: Sendable {
    /// The type of the request body, which must be `Encodable` and `Sendable`.
    associatedtype RequestBody: Encodable & Sendable = Never
    /// The type of the success response body, which must be `Decodable` and `Sendable`.
    associatedtype SuccessResponseBody: Decodable & Sendable = Never
    /// The type of the failure response body, which must be `Decodable` and `Sendable`.
    associatedtype FailureResponseBody: Decodable & Sendable = Never

    /// A unique identifier for the operation or endpoint.
    static var operationID: String { get }
    /// The path component of the HTTP request URL (relative to the base URL).
    var path: String { get }
    /// The HTTP method (e.g., `.get`, `.post`, `.put`, `.delete`) for this request.
    var method: HTTPRequest.Method { get }
    /// Additional HTTP header fields to include in the request.
    var headerFields: HTTPFields { get }
    /// The URL query items to include in the request URL.
    var queryItems: [URLQueryItem] { get }
    /// The body of the HTTP request, typed as `RequestBody`.
    var body: RequestBody { get }

    /// Encodes this request's body into `Data` for transmission over HTTP.
    ///
    /// The default implementation behaves as follows:
    /// - If `RequestBody` is `Never` or `Never?`, this method returns `nil`, indicating that the
    ///   request has no body.
    /// - Otherwise, it encodes `body` using `JSONEncoder` and returns the resulting `Data`.
    ///
    /// Conforming types may override this method to implement alternative encodings, such as:
    /// - `application/x-www-form-urlencoded`
    /// - `multipart/form-data`
    /// - Binary payloads (e.g., images, files)
    /// - Custom serialization formats
    ///
    /// - Returns: The encoded body as `Data`, or `nil` if the request has no body.
    /// - Throws: Any error thrown by the chosen encoder while encoding `body`.
    func encodeBody() throws -> Data?

    /// Builds an `HTTPRequest` (Apple's type) from this request's properties and the given base URL.
    ///
    /// The default implementation constructs an `HTTPRequest` from `method`, `path`, `headerFields`,
    /// and `queryItems` resolved against `baseURL`. Conforming types may override this to customize
    /// URL construction or apply additional per-request configuration.
    ///
    /// - Parameter baseURL: The base URL to be combined with the request's path and query items.
    /// - Returns: A fully formed `HTTPRequest` ready for sending.
    func makeHTTPRequest(baseURL: URL) -> HTTPRequest

    /// Decodes the HTTP response data into this request's `SuccessResponseBody` type.
    ///
    /// - Parameter data: The raw data returned by the HTTP response.
    /// - Returns: The decoded `SuccessResponseBody` object.
    /// - Throws: An error if decoding the response data fails.
    func decodeSuccessBody(from data: Data) throws -> SuccessResponseBody

    /// Decodes the HTTP response data into this request's `FailureResponseBody` type.
    ///
    /// - Parameter data: The raw data returned by the HTTP response.
    /// - Returns: The decoded `FailureResponseBody` object.
    /// - Throws: An error if decoding the response data fails.
    func decodeFailureBody(from data: Data) throws -> FailureResponseBody
}

// MARK: Default implementation

public extension Request {
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

public extension Request where RequestBody == Never {
    var body: Never {
        get { fatalError("\(type(of: self)) does not have a request body") }
        set {}
    }
}

public extension Request where RequestBody == Never? {
    var body: Never? {
        get { nil }
        set { fatalError("\(type(of: self)) does not have a request body") }
    }
}

public extension Request where SuccessResponseBody: Decodable {
    /// Default implementation of `decodeSuccessBody(from:)`.
    /// This method decodes the response data from JSON into the `SuccessResponseBody` type.
    /// Conformers can override this method for custom decoding behavior.
    func decodeSuccessBody(from data: Data) throws -> SuccessResponseBody {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        return try decoder.decode(SuccessResponseBody.self, from: data)
    }
}

public extension Request where FailureResponseBody: Decodable {
    /// Default implementation of `decodeFailureBody(from:)`.
    /// This method decodes the response data from JSON into the `FailureResponseBody` type.
    /// Conformers can override this method for custom decoding behavior.
    func decodeFailureBody(from data: Data) throws -> FailureResponseBody {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        return try decoder.decode(FailureResponseBody.self, from: data)
    }
}
