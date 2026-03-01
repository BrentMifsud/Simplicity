import Foundation
import HTTPTypes
@testable import Simplicity

struct MockTransport: Transport {
    let handler: @Sendable (HTTPRequest, Data?) async throws -> (Data, HTTPResponse)

    func data(
        for request: HTTPRequest,
        body: Data?,
        cachePolicy: CachePolicy,
        timeout: Duration
    ) async throws -> (Data, HTTPResponse, URL) {
        let (data, response) = try await handler(request, body)
        return (data, response, responseURL(for: request))
    }

    func upload(
        for request: HTTPRequest,
        from bodyData: Data,
        timeout: Duration
    ) async throws -> (Data, HTTPResponse, URL) {
        let (data, response) = try await handler(request, bodyData)
        return (data, response, responseURL(for: request))
    }

    /// Reconstructs a URL from the HTTPRequest's components for test response purposes.
    private func responseURL(for request: HTTPRequest) -> URL {
        var string = ""
        if let scheme = request.scheme {
            string += scheme + "://"
        }
        if let authority = request.authority {
            string += authority
        }
        if let path = request.path {
            string += path
        }
        return URL(string: string) ?? URL(string: "https://localhost")!
    }
}
