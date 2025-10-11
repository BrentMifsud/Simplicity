//
//  Middleware.swift
//  Noms
//
//  Created by Brent Mifsud on 2025-08-06.
//

public import Foundation

/// A composable, concurrency-safe hook for observing and transforming HTTP requests and responses.
/// 
/// Conform to `Middleware` to implement cross‑cutting concerns—such as authentication,
/// request signing, logging, metrics, retries, or request/response mutation—without
/// coupling them to the transport layer or individual endpoints.
/// 
/// Key characteristics:
/// - Sendable: Conformers must be safe to use across Swift concurrency domains.
/// - Composable: Multiple middleware can be chained; each one decides whether to
///   forward the request, modify it, or short‑circuit with a custom response or error.
/// - Transparent: When calling `next`, you delegate to the remainder of the chain
///   (ultimately reaching the transport). You can inspect and transform both the
///   outgoing request and the incoming response.
/// 
/// Typical use cases:
/// - Attach authentication headers or tokens
/// - Implement request signing
/// - Centralized logging or network tracing
/// - Automatic retries with backoff for idempotent requests
/// - Response validation and normalization
/// - Conditional routing or base URL rewriting
///
/// Ordering considerations:
/// - Middleware are executed in the order they are registered. Earlier middleware wrap later ones,
///   so place broader concerns (e.g., tracing) earlier and more specific concerns (e.g., auth)
///   closer to the transport if needed.
/// 
/// Cancellation and error handling:
/// - Respect task cancellation and propagate thrown errors unless intentionally handled.
/// - You may transform errors (e.g., map transport errors to domain errors) before rethrowing.
/// 
/// Thread-safety:
/// - Because the protocol is `Sendable`, any captured state must be safe for concurrent access.
///   Prefer immutable value types or isolate mutable state behind actors.
/// 
/// Example (conceptual):
/// ```swift
/// struct AuthMiddleware: Middleware {
///     func intercept<Request: HTTPRequest>(
///         request: Request,
///         baseURL: URL,
///         next: @Sendable (Request, URL) async throws -> HTTPResponse<Request.ResponseBody>
///     ) async throws -> HTTPResponse<Request.ResponseBody> {
///         var request = request
///         request.headers["Authorization"] = "Bearer \(token)"
///         let response = try await next(request, baseURL)
///         return response
///     }
/// }
/// ```
///
/// - Note: You may return a synthesized `HTTPResponse` without calling `next` to short‑circuit
///   the chain (e.g., for cached responses or feature flags).
///
/// - See also: `HTTPRequest`, `HTTPResponse`.
///
///
/// Intercepts an outgoing `HTTPRequest`, optionally mutates it, and decides whether to forward it
/// down the middleware chain by calling `next`. You may also inspect and transform the resulting
/// `HTTPResponse` before returning it.
///
/// - Parameters:
///   - request: The strongly-typed request to send. You may read, validate, or replace it before forwarding.
///   - baseURL: The current base URL that will be combined with the request’s path. You may pass a different
///     value to `next` to rewrite routing (e.g., for multi‑region failover).
///   - next: A `@Sendable` async function representing the remainder of the chain (including the transport).
///     Call `next(modifiedRequest, modifiedBaseURL)` to continue. You may call it once, multiple times
///     (e.g., retries), or not at all (short‑circuit).
///
/// - Returns: An `HTTPResponse<Request.ResponseBody>` produced by the transport or synthesized by the middleware.
///
/// - Throws: Any error thrown by downstream middleware or the transport, or errors you throw yourself
///   (e.g., validation failures, cancellation, retry exhaustion).
///
/// - Important: If you implement retries, ensure that the retried operation is safe (idempotent) or that
///   your strategy accounts for side effects. Also consider honoring `Task.isCancelled` before retrying.
public protocol Middleware: Sendable {
    func intercept<Request: HTTPRequest>(
        request: Request,
        baseURL: URL,
        next: @Sendable (
            _ request: Request,
            _ baseURL: URL
        ) async throws -> HTTPResponse<Request.ResponseBody>
    ) async throws -> HTTPResponse<Request.ResponseBody>
}
