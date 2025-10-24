//
//  ClientError.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-19.
//

public import Foundation

public nonisolated enum ClientError: Sendable, LocalizedError {
    case cancelled
    case timedOut
    case cacheMiss
    case encodingError(type: String, underlyingError: any Error)
    case transport(URLError)
    case middleware(middleware: any Middleware, underlyingError: any Error)
    case invalidResponse(String)
    case unknown(client: any HTTPClient, underlyingError: any Error)

    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .timedOut:
            "The request timed out"
        case .cancelled:
            "The request was cancelled"
        case let .encodingError(type, underlyingError):
            "Failed to encode \(type): \(underlyingError.localizedDescription)"
        case .transport(let error):
            error.localizedDescription
        case .invalidResponse(let details):
            details
        case let .middleware(middleware, underlyingError):
            "\(type(of: middleware)) threw an error:\n\(underlyingError.localizedDescription)"
        case let .unknown(client, underlyingError):
            "An unexpected error was thrown by \(type(of: client)): \(underlyingError.localizedDescription)"
        case .cacheMiss:
            "A cache value for the given request was not found"
        }
    }
}

