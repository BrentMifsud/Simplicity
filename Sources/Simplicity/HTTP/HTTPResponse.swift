//
//  HTTPResponse.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public import Foundation

/// A value type that models the outcome of an HTTP request, including status, headers,
/// final URL, and an optional, strongly‑typed response body.
///
/// HTTPResponse is generic over `ResponseBody`, which must conform to `Decodable & Sendable`.
/// This allows the transport layer (or middleware) to decode payloads into the type your
/// endpoint expects, while remaining safe to pass across Swift concurrency domains.
///
/// Key characteristics:
/// - Immutable and Sendable: Safe to share across tasks and threads.
/// - Nonisolated: Can be used from any actor context without hopping.
/// - Transparent: Carries both the decoded body (if any) and the raw bytes for custom parsing.
///
/// Typical usage:
/// - Return from a transport client after performing a request.
/// - Inspect status code and headers for control flow (e.g., retries, auth refresh).
/// - Prefer `body` for typed access; fall back to `rawData` for manual parsing or binary payloads.
///
/// Decoding considerations:
/// - `body` is optional and only present if the response was decoded into `ResponseBody`.
/// - For endpoints with no payload, use a sentinel type (e.g., `Empty`, `Data`, or `Void`-like struct)
///   that conforms to `Decodable & Sendable`, and expect `body` to be `nil` or a default value
///   depending on your transport’s decoding strategy.
///
/// Example:
/// ```swift
/// struct User: Decodable, Sendable { let id: Int; let name: String }
/// let response: HTTPResponse<User> = try await client.send(GetUserRequest(id: 42))
/// #expect(response.statusCode.isSuccess)
/// let user = try #require(response.body)
/// print(user.name)
/// ```
///
/// - See also: `HTTPRequest`, `Middleware`, `HTTPStatusCode`.
///
/// The HTTP status code returned by the server (e.g., 200, 404, 500).
/// Use this to determine success/failure or to branch on specific conditions.
/// If your codebase provides helpers (e.g., `isSuccess`), prefer those for readability.
/// public let statusCode: HTTPStatusCode
///
/// The response headers as a case‑insensitive map of header field names to values.
/// While the dictionary keys are stored as provided by the transport, header semantics
/// are case‑insensitive. Be mindful of multi‑value headers which may be joined by the transport.
/// public let headers: [String: String]
///
/// The final URL associated with the response, if known. This may include redirects
/// followed by the transport. Useful for debugging, caching keys, or metrics.
/// public let url: URL?
///
/// The decoded response body, if decoding was attempted and succeeded. This value is
/// `nil` for empty responses, when decoding is intentionally skipped, or if the transport
/// chose not to surface a decoding error (implementation‑defined).
/// public let body: ResponseBody?
///
/// The raw response payload as bytes, if captured by the transport. Use this when:
/// - You need to perform custom parsing (e.g., protobuf, XML, multipart).
/// - You want to log or persist the exact bytes.
/// Note: This may be large; avoid copying unnecessarily.
/// public let rawData: Data?
///
/// Creates a new HTTPResponse instance.
/// - Parameters:
///   - statusCode: The HTTP status code returned by the server.
///   - headers: The response headers as a dictionary of field names to values.
///   - url: The final URL associated with the response, if available.
///   - httpBody: The decoded response body, if present and successfully decoded.
///   - rawData: The raw response bytes, if captured by the transport.
public nonisolated struct HTTPResponse<ResponseBody: Decodable & Sendable>: Sendable {
    public let statusCode: HTTPStatusCode
    public let url: URL
    public let headers: [String: String]
    public let httpBody: ResponseBody

    public init(
        statusCode: HTTPStatusCode,
        url: URL,
        headers: [String: String],
        httpBody: ResponseBody,
    ) {
        self.statusCode = statusCode
        self.url = url
        self.headers = headers
        self.httpBody = httpBody
    }
}
