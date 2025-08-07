//
//  HTTPRequest.swift
//  Noms
//
//  Created by Brent Mifsud on 2025-08-06.
//

import Foundation

public protocol HTTPRequest: Sendable {
    associatedtype RequestBody: Encodable & Sendable
    associatedtype ResponseBody: Decodable & Sendable
    static var operationID: String { get }
    var path: String { get }
    var httpMethod: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem] { get }
    var httpBody: RequestBody { get }
    
    func encodeURLRequest(baseURL: URL) throws -> URLRequest
    func decodeResponseData(_ data: Data) throws -> ResponseBody
}
