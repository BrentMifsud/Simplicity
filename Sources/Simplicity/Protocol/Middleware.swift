//
//  Middleware.swift
//  Noms
//
//  Created by Brent Mifsud on 2025-08-06.
//

import Foundation

public struct HTTPResponse<ResponseBody: Sendable>: Sendable {
    public let statusCode: HTTPStatusCode
    public let headers: [String: String]
    public let url: URL?
    public let body: ResponseBody?
    public let rawData: Data?
    
    public init(
        statusCode: HTTPStatusCode,
        headers: [String: String],
        url: URL?,
        body: ResponseBody?,
        rawData: Data?
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.url = url
        self.body = body
        self.rawData = rawData
    }
}

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
