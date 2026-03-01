//
//  Response.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation
public import HTTPTypes

/// A value type that models the outcome of an HTTP request, wrapping Apple's `HTTPResponse` and
/// adding on-demand decoding for both success and failure bodies.
///
/// `Response` carries the transport-level details (status, headers, final URL, raw bytes) and
/// defers decoding until you explicitly request it via `decodeSuccessBody()` or `decodeFailureBody()`.
/// This is useful when you need to inspect the status or headers before deciding how to decode,
/// or when endpoints can return different payload shapes for success vs. error cases.
///
/// - Generic Parameters:
///   - `Success`: The decodable type expected when the response indicates success.
///   - `Failure`: The decodable type expected when the response indicates an error.
///
/// Typical usage:
/// ```swift
/// struct User: Decodable, Sendable { let id: Int; let name: String }
/// struct APIErrorPayload: Decodable, Sendable { let code: Int; let message: String }
/// let response: Response<User, APIErrorPayload> = try await client.send(GetUserRequest(id: 42))
/// if response.status.kind == .successful {
///     let user = try response.decodeSuccessBody()
///     print(user.name)
/// } else {
///     let errorPayload = try response.decodeFailureBody()
///     print("API error: \(errorPayload.code) - \(errorPayload.message)")
/// }
/// ```
public nonisolated struct Response<Success: Decodable & Sendable, Failure: Decodable & Sendable>: Sendable {
    /// The underlying Apple HTTP response carrying status and header fields.
    public let httpResponse: HTTPResponse

    /// The final URL associated with the response.
    /// May reflect redirects followed by the transport stack.
    public let url: URL

    /// The raw response payload as bytes.
    /// Use this for custom parsing, logging, or when you don't need typed decoding.
    public let body: Data

    /// The HTTP response status (e.g., `.ok`, `.notFound`, `.internalServerError`).
    @inlinable
    public var status: HTTPResponse.Status { httpResponse.status }

    /// The response header fields.
    @inlinable
    public var headerFields: HTTPFields { httpResponse.headerFields }

    private let successBodyDecoder: @Sendable (Data) throws -> Success
    private let failureBodyDecoder: @Sendable (Data) throws -> Failure

    init(
        httpResponse: HTTPResponse,
        url: URL,
        body: Data,
        successBodyDecoder: @escaping @Sendable (Data) throws -> Success,
        failureBodyDecoder: @escaping @Sendable (Data) throws -> Failure
    ) {
        self.httpResponse = httpResponse
        self.url = url
        self.body = body
        self.successBodyDecoder = successBodyDecoder
        self.failureBodyDecoder = failureBodyDecoder
    }

    /// Decodes `body` into the `Success` type using the configured success decoder.
    /// - Returns: A value of type `Success`.
    /// - Throws: `ClientError.decodingError` wrapping the underlying error and the raw response body.
    public func decodeSuccessBody() throws -> Success {
        do {
            return try successBodyDecoder(body)
        } catch {
            throw ClientError.decodingError(
                type: String(describing: Success.self),
                responseBody: body,
                underlyingError: error
            )
        }
    }

    /// Decodes `body` into the `Failure` type using the configured failure decoder.
    /// - Returns: A value of type `Failure`.
    /// - Throws: `ClientError.decodingError` wrapping the underlying error and the raw response body.
    public func decodeFailureBody() throws -> Failure {
        do {
            return try failureBodyDecoder(body)
        } catch {
            throw ClientError.decodingError(
                type: String(describing: Failure.self),
                responseBody: body,
                underlyingError: error
            )
        }
    }
}

extension Response where Success == Never {
    init(
        httpResponse: HTTPResponse,
        url: URL,
        body: Data,
        failureBodyDecoder: @escaping @Sendable (Data) throws -> Failure
    ) {
        self.init(
            httpResponse: httpResponse,
            url: url,
            body: body,
            successBodyDecoder: { _ in
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

extension Response where Failure == Never {
    init(
        httpResponse: HTTPResponse,
        url: URL,
        body: Data,
        successBodyDecoder: @escaping @Sendable (Data) throws -> Success
    ) {
        self.init(
            httpResponse: httpResponse,
            url: url,
            body: body,
            successBodyDecoder: successBodyDecoder,
            failureBodyDecoder: { _ in
                fatalError("decodeFailureBody should be unreachable when Failure == Never")
            }
        )
    }

    @available(*, unavailable, message: "No failure body is available when Failure == Never.")
    public func decodeFailureBody() throws -> Failure {
        fatalError("unavailable")
    }
}
