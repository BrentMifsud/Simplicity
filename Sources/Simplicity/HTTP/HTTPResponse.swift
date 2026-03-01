//
//  HTTPResponse.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation

/// A value type that models the outcome of an HTTP request, including status, headers,
/// final URL, and raw response bytes, with on-demand decoding for both success and failure bodies.
///
/// `HTTPResponse` carries the transport-level details of a response and defers decoding until
/// you explicitly request it via `decodeSuccessBody()` or `decodeFailureBody()`. This is useful
/// when you need to inspect the status code or headers before deciding how to decode, or when
/// endpoints can return different payload shapes for success vs. error cases.
///
/// - Generic Parameters:
///   - `Success`: The decodable type expected when the response indicates success.
///   - `Failure`: The decodable type expected when the response indicates an error.
///
/// Typical usage:
/// ```swift
/// struct User: Decodable, Sendable { let id: Int; let name: String }
/// struct APIErrorPayload: Decodable, Sendable { let code: Int; let message: String }
/// let response: HTTPResponse<User, APIErrorPayload> = try await client.send(GetUserRequest(id: 42))
/// if response.statusCode.isSuccess {
///     let user = try response.decodeSuccessBody()
///     print(user.name)
/// } else {
///     let errorPayload = try response.decodeFailureBody()
///     print("API error: \(errorPayload.code) - \(errorPayload.message)")
/// }
/// ```
///
/// Decoding considerations:
/// - Both decode methods throw if decoding fails. For endpoints that may return an empty body,
///   consider using tolerant types (e.g., `Data`, a custom empty wrapper, or optional fields).
/// - If you need the raw bytes for logging or custom parsing, use `httpBody` directly.
public nonisolated struct HTTPResponse<Success: Decodable & Sendable, Failure: Decodable & Sendable>: Sendable {
    /// The HTTP status code returned by the server (e.g., 200, 404, 500).
    /// Use helpers like `isSuccess` when available to branch on outcomes.
    public let statusCode: HTTPStatusCode
    /// The final URL associated with the response.
    /// May reflect redirects followed by the transport stack.
    public let url: URL
    /// The response headers as a map of field names to values.
    /// Header names are case-insensitive by HTTP semantics; multi-value headers may be joined.
    public let headers: [String: String]
    /// The raw response payload as bytes.
    /// Use this for custom parsing, logging, or when you don't need typed decoding.
    public let httpBody: Data

    private let successBodyDecoder: @Sendable (Data) throws -> Success
    private let failureBodyDecoder: @Sendable (Data) throws -> Failure

    init(
        statusCode: HTTPStatusCode,
        url: URL,
        headers: [String: String],
        httpBody: Data,
        successBodyDecoder: @escaping @Sendable (Data) throws -> Success,
        failureBodyDecoder: @escaping @Sendable (Data) throws -> Failure
    ) {
        self.statusCode = statusCode
        self.url = url
        self.headers = headers
        self.httpBody = httpBody
        self.successBodyDecoder = successBodyDecoder
        self.failureBodyDecoder = failureBodyDecoder
    }

    /// Decodes `httpBody` into the `Success` type using the configured success decoder.
    /// - Returns: A value of type `Success`.
    /// - Throws: `ClientError.decodingError` wrapping the underlying error and the raw response body.
    public func decodeSuccessBody() throws -> Success {
        do {
            return try successBodyDecoder(httpBody)
        } catch {
            throw ClientError.decodingError(
                type: String(describing: Success.self),
                responseBody: httpBody,
                underlyingError: error
            )
        }
    }

    /// Decodes `httpBody` into the `Failure` type using the configured failure decoder.
    /// - Returns: A value of type `Failure`.
    /// - Throws: `ClientError.decodingError` wrapping the underlying error and the raw response body.
    public func decodeFailureBody() throws -> Failure {
        do {
            return try failureBodyDecoder(httpBody)
        } catch {
            throw ClientError.decodingError(
                type: String(describing: Failure.self),
                responseBody: httpBody,
                underlyingError: error
            )
        }
    }
}

extension HTTPResponse where Success == Never {
    /// Creates a new `HTTPResponse` for failure-only responses (`Success == Never`).
    /// - Parameters:
    ///   - statusCode: The HTTP status code returned by the server.
    ///   - url: The final URL associated with the response.
    ///   - headers: The response headers as a dictionary of field names to values.
    ///   - httpBody: The raw response bytes.
    ///   - failureBodyDecoder: A closure that decodes `httpBody` into `Failure`.
    init(
        statusCode: HTTPStatusCode,
        url: URL,
        headers: [String: String],
        httpBody: Data,
        failureBodyDecoder: @escaping @Sendable (Data) throws -> Failure
    ) {
        self.init(
            statusCode: statusCode,
            url: url,
            headers: headers,
            httpBody: httpBody,
            successBodyDecoder: { _ in
                // This path should be statically unreachable when Success == Never
                fatalError("decodeSuccessBody should be unreachable when Success == Never")
            },
            failureBodyDecoder: failureBodyDecoder
        )
    }

    @available(*, unavailable, message: "No success body is available when Success == Never.")
    public func decodeSuccessBody() throws -> Success {
        fatalError("unavailable")
    }
}

extension HTTPResponse where Failure == Never {
    /// Creates a new `HTTPResponse` for success-only responses (`Failure == Never`).
    /// - Parameters:
    ///   - statusCode: The HTTP status code returned by the server.
    ///   - url: The final URL associated with the response.
    ///   - headers: The response headers as a dictionary of field names to values.
    ///   - httpBody: The raw response bytes.
    ///   - successBodyDecoder: A closure that decodes `httpBody` into `Success`.
    init(
        statusCode: HTTPStatusCode,
        url: URL,
        headers: [String: String],
        httpBody: Data,
        successBodyDecoder: @escaping @Sendable (Data) throws -> Success
    ) {
        self.init(
            statusCode: statusCode,
            url: url,
            headers: headers,
            httpBody: httpBody,
            successBodyDecoder: successBodyDecoder,
            failureBodyDecoder: { _ in
                // This path should be statically unreachable when Failure == Never
                fatalError("decodeFailureBody should be unreachable when Failure == Never")
            }
        )
    }

    @available(*, unavailable, message: "No failure body is available when Failure == Never.")
    public func decodeFailureBody() throws -> Failure {
        fatalError("unavailable")
    }
}
