//
//  HTTPMethod.swift
//  Noms
//
//  Created by Brent Mifsud on 2025-08-06.
//

/// Represents the standard HTTP methods used in network requests.
public enum HTTPMethod: String, Sendable {
    /// The GET method requests a representation of the specified resource.
    case get = "GET"
    /// The POST method submits data to be processed to a specified resource.
    case post = "POST"
    /// The PUT method replaces all current representations of the target resource with the uploaded content.
    case put = "PUT"
    /// The PATCH method applies partial modifications to a resource.
    case patch = "PATCH"
    /// The DELETE method deletes the specified resource.
    case delete = "DELETE"
    /// The HEAD method asks for a response identical to that of a GET request, but without the response body.
    case head = "HEAD"
    /// The OPTIONS method describes the communication options for the target resource.
    case options = "OPTIONS"
    /// The TRACE method performs a message loop-back test along the path to the target resource.
    case trace = "TRACE"
    /// The CONNECT method establishes a tunnel to the server identified by the target resource.
    case connect = "CONNECT"
}
