//
//  MiddlewareSpy.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-08-06.
//

import Foundation
import Simplicity

actor MiddlewareSpy<Req: HTTPRequest>: Middleware {
    private(set) var callTime: Date?
    private let mutation: ((Req, URL) -> (Req, URL))?
    private let postResponseOperation: ((HTTPResponse<Req.ResponseBody>) -> Void)?
    
    init(
        mutation: ((Req, URL) -> (Req, URL))? = nil,
        postResponseOperation: ((HTTPResponse<Req.ResponseBody>) -> Void)? = nil
    ) {
        self.mutation = mutation
        self.postResponseOperation = postResponseOperation
    }
    
    func intercept<Request: HTTPRequest>(
        request: Request,
        baseURL: URL,
        next: @Sendable (Request, URL) async throws -> HTTPResponse<Request.ResponseBody>
    ) async throws -> HTTPResponse<Request.ResponseBody> {
        callTime = Date()
        
        var requestVar = request
        var baseURLVar = baseURL
        
        if let mutation = mutation {
            let (newRequest, newBaseURL) = mutation(requestVar as! Req, baseURLVar)
            requestVar = newRequest as! Request
            baseURLVar = newBaseURL
        }
        
        let response = try await next(requestVar, baseURLVar)
        
        if let postResponseOperation = postResponseOperation {
            postResponseOperation(response as! HTTPResponse<Req.ResponseBody>)
        }
        
        return response
    }
}
