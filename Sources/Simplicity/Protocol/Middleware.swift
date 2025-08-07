//
//  Middleware.swift
//  Noms
//
//  Created by Brent Mifsud on 2025-08-06.
//

import Foundation

public protocol Middleware: Sendable {
    func intercept(
        request: URLRequest,
        baseURL: URL,
        operationID: String,
        next: @Sendable (_ request: URLRequest, _ baseURL: URL, _ operationID: String) async throws -> (data: Data, response: HTTPURLResponse)
    ) async throws -> (data: Data, response: HTTPURLResponse)
}
