//
//  HTTPStatusCode.swift
//  Noms
//
//  Created by Brent Mifsud on 2025-08-06.
//

import Foundation

/// Represents HTTP status codes as defined in RFC 7231 and related RFCs.
/// Provides convenient typed access to common HTTP response codes.
public enum HTTPStatusCode: Int, Sendable {
    // MARK: - 1xx: Informational responses
    
    /// The request has been received and the process can continue.
    case `continue` = 100
    /// The server is switching protocols as requested by the client.
    case switchingProtocols = 101
    /// The server is processing the request but no response is available yet.
    case processing = 102
    /// The server is sending preliminary information before a final response.
    case earlyHints = 103
    
    // MARK: - 2xx: Success

    /// The request was successful.
    case ok = 200
    /// The request has been fulfilled and resulted in a new resource being created.
    case created = 201
    /// The request has been accepted for processing, but the processing is not complete.
    case accepted = 202
    /// The returned meta-information is not the definitive set as available from the origin server.
    case nonAuthoritativeInformation = 203
    /// The server successfully processed the request, but is not returning any content.
    case noContent = 204
    /// The server successfully processed the request, but is not returning any content and requires the client to reset the document view.
    case resetContent = 205
    /// The server is delivering only part of the resource due to a range header sent by the client.
    case partialContent = 206
    /// The message body contains a representation consisting of multiple separate parts.
    case multiStatus = 207
    /// The members of a DAV binding have already been enumerated in a previous reply to this request.
    case alreadyReported = 208
    /// The server has fulfilled a GET request for the resource, and the response is a representation of the result of one or more instance-manipulations applied to the current instance.
    case imUsed = 226
    
    // MARK: - 3xx: Redirection

    /// Indicates multiple options for the resource from which the client may choose.
    case multipleChoices = 300
    /// The resource has been moved permanently to a new URL.
    case movedPermanently = 301
    /// The resource resides temporarily under a different URL.
    case found = 302
    /// The response to the request can be found under another URI using a GET method.
    case seeOther = 303
    /// Indicates that the resource has not been modified since the last request.
    case notModified = 304
    /// The requested resource is only available through a proxy.
    case useProxy = 305
    /// No longer used; originally meant "switch proxy".
    case unused = 306
    /// The resource has been temporarily moved to another URL.
    case temporaryRedirect = 307
    /// The resource has been permanently moved to another URL.
    case permanentRedirect = 308
    
    // MARK: -  4xx: Client Error
    
    /// The request could not be understood by the server due to malformed syntax.
    case badRequest = 400
    /// The request requires user authentication.
    case unauthorized = 401
    /// Payment is required to access the resource.
    case paymentRequired = 402
    /// The server understood the request, but refuses to authorize it.
    case forbidden = 403
    /// The requested resource could not be found.
    case notFound = 404
    /// The method specified in the request is not allowed for the resource.
    case methodNotAllowed = 405
    /// The requested resource is not available in a format acceptable to the client.
    case notAcceptable = 406
    /// Proxy authentication is required to access the resource.
    case proxyAuthenticationRequired = 407
    /// The server timed out waiting for the request.
    case requestTimeout = 408
    /// The request could not be completed due to a conflict with the current state of the resource.
    case conflict = 409
    /// The resource requested is no longer available and will not be available again.
    case gone = 410
    /// The request did not specify the length of its content, which is required by the requested resource.
    case lengthRequired = 411
    /// The server does not meet one of the preconditions that the requester put on the request.
    case preconditionFailed = 412
    /// The request entity is larger than limits defined by the server.
    case payloadTooLarge = 413
    /// The URI provided was too long for the server to process.
    case uriTooLong = 414
    /// The media format of the requested data is not supported by the server.
    case unsupportedMediaType = 415
    /// The client has asked for a portion of the file, but the server cannot supply that portion.
    case rangeNotSatisfiable = 416
    /// The server cannot meet the requirements of the Expect request-header field.
    case expectationFailed = 417
    /// The server refuses to brew coffee because it is a teapot.
    case imATeapot = 418
    /// The request was directed at a server that is not able to produce a response.
    case misdirectedRequest = 421
    /// The request was well-formed but was unable to be followed due to semantic errors.
    case unprocessableEntity = 422
    /// The resource is locked.
    case locked = 423
    /// The request failed due to failure of a previous request.
    case failedDependency = 424
    /// The server is unwilling to risk processing a request that might be replayed.
    case tooEarly = 425
    /// The client should switch to a different protocol such as TLS/1.0.
    case upgradeRequired = 426
    /// The origin server requires the request to be conditional.
    case preconditionRequired = 428
    /// The user has sent too many requests in a given amount of time.
    case tooManyRequests = 429
    /// The server is unwilling to process the request because its header fields are too large.
    case requestHeaderFieldsTooLarge = 431
    /// The resource is unavailable due to legal reasons.
    case unavailableForLegalReasons = 451
    
    // MARK: - 5xx: Server Error
    
    /// The server encountered an unexpected condition which prevented it from fulfilling the request.
    case internalServerError = 500
    /// The server does not support the functionality required to fulfill the request.
    case notImplemented = 501
    /// The server, while acting as a gateway or proxy, received an invalid response from the upstream server.
    case badGateway = 502
    /// The server is currently unable to handle the request due to temporary overload or maintenance.
    case serviceUnavailable = 503
    /// The server, while acting as a gateway or proxy, did not receive a timely response.
    case gatewayTimeout = 504
    /// The server does not support the HTTP protocol version used in the request.
    case httpVersionNotSupported = 505
    /// The server has an internal configuration error: the chosen variant resource is configured to engage in transparent content negotiation itself.
    case variantAlsoNegotiates = 506
    /// The server is unable to store the representation needed to complete the request.
    case insufficientStorage = 507
    /// The server detected an infinite loop while processing the request.
    case loopDetected = 508
    /// Further extensions to the request are required for the server to fulfill it.
    case notExtended = 510
    /// The client needs to authenticate to gain network access.
    case networkAuthenticationRequired = 511
    
    /// Returns true if the status code represents a 2xx Success response.
    public var isSuccess: Bool {
        (200..<300) ~= self.rawValue
    }
}
