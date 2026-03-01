//
//  MiddlewareSpy.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-08-06.
//

import Foundation
import Simplicity

actor MiddlewareSpy: Middleware {
    private(set) var callTime: Date?
    private let thrownError: (any Error)?
    private let mutation: ((MiddlewareRequest) -> (MiddlewareRequest))?
    private let postResponseOperation: ((MiddlewareResponse) -> Void)?

    init(
        thrownError: (any Error)? = nil,
        mutation: ((MiddlewareRequest) -> (MiddlewareRequest))? = nil,
        postResponseOperation: ((MiddlewareResponse) -> Void)? = nil
    ) {
        self.thrownError = thrownError
        self.mutation = mutation
        self.postResponseOperation = postResponseOperation
    }

    func intercept(
        request: MiddlewareRequest,
        next: nonisolated(nonsending) @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse
    ) async throws -> MiddlewareResponse {
        callTime = Date()

        if let thrownError {
            throw thrownError
        }

        var request = request

        if let mutation {
            request = mutation(request)
        }

        let response = try await next(request)

        if let postResponseOperation = postResponseOperation {
            postResponseOperation(response)
        }

        return response
    }
}
