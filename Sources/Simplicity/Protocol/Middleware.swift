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
/// - Each middleware receives a strongly‑typed `request`, the current `baseURL`, and a `next` closure
///   representing the remainder of the chain.
/// - You may short‑circuit by returning a synthesized `HTTPResponse` without calling `next` (e.g., cached data),
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
/// - You may validate and mutate the outgoing request (e.g., add headers, sign requests, rewrite paths/base URL).
/// - You can inspect and transform the incoming `HTTPResponse` before returning it (e.g., normalize headers,
///   decode/unwrap envelopes, attach metadata).
/// - For typed access, prefer `HTTPResponse.body`; fall back to `rawData` for custom parsing.
///
/// Example (conceptual):
/// ```swift
/// struct AuthMiddleware: Middleware {
///     func intercept<Request: HTTPRequest>(
///         request: Request,
///         baseURL: URL,
///         next: nonisolated(nonsending) @Sendable (Request, URL) async throws -> HTTPResponse<Request.ResponseBody>
///     ) async throws -> HTTPResponse<Request.ResponseBody> {
///         var request = request
///         request.headers["Authorization"] = "Bearer \(token)"
///
///         // Optional: validate cancellation before work that cannot be undone
///         try Task.checkCancellation()
///
///         let response = try await next(request, baseURL)
///         return response
///     }
/// }
/// ```
///
/// - Note: Do not retain or escape the `next` closure beyond the scope of `intercept`.
/// - See also: `HTTPRequest`, `HTTPResponse`.
///
/// Intercepts an outgoing `HTTPRequest`, optionally mutates it, and decides whether to forward it
/// down the middleware chain by calling `next`. You may also inspect and transform the resulting
/// `HTTPResponse` before returning it.
///
/// - Parameters:
///   - request: The strongly‑typed request to send. You may read, validate, or replace it before forwarding.
///   - baseURL: The current base URL that will be combined with the request’s path. You may pass a different
///     value to `next` to rewrite routing (e.g., for multi‑region failover).
///   - next: A `nonisolated(nonsending) @Sendable` async function representing the remainder of the chain
///     (including the transport). Call `next(modifiedRequest, modifiedBaseURL)` to continue.
///     You may call it once, multiple times (e.g., retries), or not at all (short‑circuit). Do not store or escape this closure.
///
/// - Returns: An `HTTPResponse<Request.ResponseBody>` produced by the transport or synthesized by the middleware.
///
/// - Throws: Any error thrown by downstream middleware or the transport, or errors you throw yourself
///   (e.g., validation failures, cancellation, retry exhaustion).
///
/// - Important: If you implement retries, ensure that the retried operation is safe (idempotent) or that
///   your strategy accounts for side effects. Consider honoring `Task.isCancelled` before retrying and between attempts.
public protocol Middleware: Sendable {
    func intercept<Request: HTTPRequest>(
        request: Request,
        baseURL: URL,
        next: nonisolated(nonsending) @Sendable (
            _ request: Request,
            _ baseURL: URL
        ) async throws -> HTTPResponse<Request.ResponseBody>
    ) async throws -> HTTPResponse<Request.ResponseBody>
}
