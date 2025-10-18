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
    private let mutation: ((Middleware.Request) -> (Middleware.Request))?
    private let postResponseOperation: ((Middleware.Response) -> Void)?

    init(
        mutation: ((Middleware.Request) -> (Middleware.Request))? = nil,
        postResponseOperation: ((Middleware.Response) -> Void)? = nil
    ) {
        self.mutation = mutation
        self.postResponseOperation = postResponseOperation
    }

    func intercept(
        request: (Middleware.Request),
        next: nonisolated(nonsending) @Sendable (Middleware.Request) async throws -> Middleware.Response
    ) async throws -> (
        statusCode: Simplicity.HTTPStatusCode,
        url: URL,
        headers: [String : String],
        httpBody: Data
    ) {
        callTime = Date()

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
