//
//  Middleware.swift
//  Noms
//
//  Created by Brent Mifsud on 2025-08-06.
//

public import Foundation

/// A composable, concurrency‑safe hook for observing and transforming HTTP requests and responses.
///
/// Conform to `Middleware` to implement cross‑cutting concerns—such as authentication,
/// request signing, logging, metrics, retries, or request/response mutation—without
/// coupling them to the transport layer or individual endpoints.
///
/// Composition and ordering:
/// - Middleware are executed in the order they are registered. Earlier middleware wrap later ones.
///   Place broad concerns (e.g., tracing) earlier and specific concerns (e.g., auth) closer to the transport.
/// - Each middleware receives a `Middleware.Request` tuple (method, baseURL, headers, httpBody) and a `next` closure
///   representing the remainder of the chain.
/// - You may short‑circuit by returning a synthesized `Middleware.Response` without calling `next` (e.g., cached data),
///   or call `next` one or multiple times (e.g., retries, shadow traffic) before returning.
///
/// Concurrency and safety:
/// - `Middleware` is `Sendable`: any captured state must be safe for concurrent access. Prefer immutable
///   value types or isolate mutable state behind actors.
/// - The `next` parameter is declared as `nonisolated(nonsending) @Sendable`. It is safe to invoke from any
///   actor context, but it must not be stored or sent across isolation boundaries. Treat it as an ephemeral
///   capability that you call within the scope of `intercept`.
/// - Respect task cancellation and check `Task.isCancelled` where appropriate, especially in retry loops.
///
/// Error handling:
/// - Propagate thrown errors unless you intentionally handle or transform them.
/// - You may map transport or decoding errors to domain‑specific errors before rethrowing.
/// - If implementing retries, ensure the operation is idempotent or your strategy accounts for side effects.
///
/// Request/response transformation:
/// - You may validate and mutate the outgoing request tuple (e.g., add headers, sign requests, rewrite paths/base URL).
/// - You can inspect and transform the incoming `Middleware.Response` tuple before returning it (e.g., normalize headers,
///   decode/unwrap envelopes, attach metadata).
///
/// Example (conceptual):
/// ```swift
/// struct AuthMiddleware: Middleware {
///     let tokenProvider: () -> String
///
///     func intercept(
///         request: Middleware.Request,
///         next: nonisolated(nonsending) @Sendable (Middleware.Request) async throws -> Middleware.Response
///     ) async throws -> Middleware.Response {
///         var req = request
///         // Inject/override authorization header
///         req.headers["Authorization"] = "Bearer \(tokenProvider())"
///
///         // Optional: validate cancellation before work that cannot be undone
///         try Task.checkCancellation()
///
///         // Continue the chain with the possibly modified request
///         let response = try await next(req)
///         return response
///     }
/// }
/// ```
///
/// Intercepts an outgoing request, optionally mutates it, and decides whether to forward it
/// down the middleware chain by calling `next`. You may also inspect and transform the resulting
/// `Middleware.Response` before returning it.
///
/// - Parameters:
///   - request: The current request tuple `(httpMethod: HTTPMethod, baseURL: URL, headers: [String: String], httpBody: Data?)`.
///     You may read, validate, or replace any of its fields before forwarding.
///   - next: A `nonisolated(nonsending) @Sendable` async function representing the remainder of the chain
///     (including the transport). Call `next(modifiedRequest)` to continue. You may call it once, multiple
///     times (e.g., retries), or not at all (short‑circuit). Do not store or escape this closure.
///
/// - Returns: A `Middleware.Response` tuple `(statusCode: HTTPStatusCode, url: URL, headers: [String: String], httpBody: Data)`
///   produced by the transport or synthesized by the middleware.
///
/// - Throws: Any error thrown by downstream middleware or the transport, or errors you throw yourself
///   (e.g., validation failures, cancellation, retry exhaustion).
///
/// - Important: If you implement retries, ensure that the retried operation is safe (idempotent) or that
///   your strategy accounts for side effects. Consider honoring `Task.isCancelled` before retrying and between attempts.
public protocol Middleware: Sendable {
    func intercept(
        request: Middleware.Request,
        next: nonisolated(nonsending) @Sendable (Middleware.Request) async throws -> Middleware.Response
    ) async throws -> Middleware.Response
}

public extension Middleware {
    typealias Request = (
        operationID: String,
        httpMethod: HTTPMethod,
        baseURL: URL,
        path: String,
        queryItems: [URLQueryItem],
        headers: [String: String],
        httpBody: Data?
    )

    typealias Response = (
        statusCode: HTTPStatusCode,
        url: URL,
        headers: [String: String],
        httpBody: Data
    )

    /// Builds the absolute URL by appending this request's `path` and `queryItems` to `baseURL`.
    ///
    /// - Parameter request: The middleware request
    /// - Returns: A `URL` representing the full endpoint for this request.
    func requestURL(request: Middleware.Request) -> URL {
        let url = request.baseURL.appending(path: request.path)

        guard !request.queryItems.isEmpty else {
            return url
        }

        return url.appending(queryItems: request.queryItems)
    }
}

