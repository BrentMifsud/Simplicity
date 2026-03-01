//
//  Middleware.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-08-06.
//

import Foundation

/// A composable, concurrency-safe hook for observing and transforming HTTP requests and responses.
///
/// Conform to `Middleware` to implement cross-cutting concerns—such as authentication,
/// request signing, logging, metrics, retries, or request/response mutation—without
/// coupling them to the transport layer or individual endpoints.
///
/// Composition and ordering:
/// - Middleware are executed in the order they are registered. Earlier middleware wrap later ones.
///   Place broad concerns (e.g., tracing) earlier and specific concerns (e.g., auth) closer to the transport.
/// - Each middleware receives a `MiddlewareRequest` (wrapping Apple's `HTTPRequest` plus body and metadata) and
///   a `next` closure representing the remainder of the chain.
/// - You may short-circuit by returning a synthesized `MiddlewareResponse` without calling `next` (e.g., cached data),
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
/// - You may map transport or decoding errors to domain-specific errors before rethrowing.
/// - If implementing retries, ensure the operation is idempotent or your strategy accounts for side effects.
///
/// Request/response transformation:
/// - You may validate and mutate the outgoing `MiddlewareRequest` (e.g., add headers, sign requests, rewrite URLs).
/// - You can inspect and transform the incoming `MiddlewareResponse` before returning it (e.g., normalize headers,
///   decode/unwrap envelopes, attach metadata).
///
/// Example:
/// ```swift
/// struct AuthMiddleware: Middleware {
///     let tokenProvider: () -> String
///
///     func intercept(
///         request: MiddlewareRequest,
///         next: nonisolated(nonsending) @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse
///     ) async throws -> MiddlewareResponse {
///         var req = request
///         req.httpRequest.headerFields[.authorization] = "Bearer \(tokenProvider())"
///         try Task.checkCancellation()
///         return try await next(req)
///     }
/// }
/// ```
public protocol Middleware: Sendable {
    func intercept(
        request: MiddlewareRequest,
        next: nonisolated(nonsending) @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse
    ) async throws -> MiddlewareResponse
}

public extension Middleware {
    /// Convenience typealias so middleware authors can write `Middleware.Request`.
    typealias Request = MiddlewareRequest

    /// Convenience typealias so middleware authors can write `Middleware.Response`.
    typealias Response = MiddlewareResponse
}
