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
    private let mutation: (@Sendable (URLRequest, URL, String) -> (URLRequest, URL, String))?
    private let postResponseOperation: ((Data, HTTPURLResponse) -> Void)?
    
    init(
        mutation: (@Sendable (URLRequest, URL, String) -> (URLRequest, URL, String))? = nil,
        postResponseOperation: ((Data, HTTPURLResponse) -> Void)? = nil
    ) {
        self.mutation = mutation
        self.postResponseOperation = postResponseOperation
    }
    
    func intercept(
        request: URLRequest,
        baseURL: URL,
        operationID: String,
        next: @Sendable (URLRequest, URL, String) async throws -> (data: Data, response: HTTPURLResponse)
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        callTime = Date()
        
        var request = request
        var baseURL = baseURL
        var operationID = operationID
        
        if let mutation {
            let (newRequest, newBaseURL, newOperationID) = mutation(request, baseURL, operationID)
            request = newRequest
            baseURL = newBaseURL
            operationID = newOperationID
        }
        
        if let postResponseOperation {
            let response = try await next(request, baseURL, operationID)
            postResponseOperation(response.data, response.response)
            return response
        } else {
            return try await next(request, baseURL, operationID)
        }
    }
}
