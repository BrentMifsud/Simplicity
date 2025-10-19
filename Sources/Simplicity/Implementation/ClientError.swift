//
//  ClientError.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-19.
//

public import Foundation

public nonisolated enum ClientError: Sendable, LocalizedError {
    case cancelled
    case encodingError(underlyingError: any Error)
    case transport(URLError)
    case middleware(middleware: any Middleware, underlyingError: any Error)
    case invalidResponse(String)
    case unknown(client: any HTTPClient, underlyingError: any Error)

    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            "The request was cancelled"
        case .encodingError(let underlyingError):
            "Failed to encode the request body:\n\(underlyingError.localizedDescription)"
        case .transport(let error):
            error.localizedDescription
        case .invalidResponse(let details):
            details
        case let .middleware(middleware, underlyingError):
            "\(type(of: middleware)) threw an error:\n\(underlyingError.localizedDescription)"
        case let .unknown(client, underlyingError):
            "An unexpected error was thrown by \(type(of: client)): \(underlyingError.localizedDescription)"
        }
    }
}
