public import Foundation
public import HTTPTypes
import HTTPTypesFoundation
#if canImport(FoundationNetworking)
public import FoundationNetworking
#endif

/// A ``Transport`` backed by a real `URLSession`.
///
/// This is the default transport used by ``URLSessionClient`` when no custom transport is provided.
/// It handles all URLSession-specific concerns internally:
/// - Converting `HTTPRequest` to `URLRequest` (via `HTTPTypesFoundation`)
/// - Applying body, cache policy, and timeout to the `URLRequest`
/// - Casting `URLResponse` to `HTTPURLResponse` and converting to `HTTPResponse`
/// - Extracting the final response URL (which may differ after redirects)
public struct URLSessionTransport: Transport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(
        for request: HTTPRequest,
        body: Data?,
        cachePolicy: CachePolicy,
        timeout: Duration
    ) async throws -> (Data, HTTPResponse, URL) {
        var urlRequest = try makeURLRequest(from: request)
        urlRequest.httpBody = body
        urlRequest.cachePolicy = cachePolicy.urlRequestCachePolicy
        urlRequest.timeoutInterval = TimeInterval(timeout.components.seconds)

        let (data, response) = try await session.data(for: urlRequest)
        return try processResponse(response, data: data, fallbackURL: urlRequest.url)
    }

    public func upload(
        for request: HTTPRequest,
        from bodyData: Data,
        timeout: Duration
    ) async throws -> (Data, HTTPResponse, URL) {
        var urlRequest = try makeURLRequest(from: request)
        // Upload requests pass body data separately; don't set it on the URLRequest.
        urlRequest.httpBody = nil
        urlRequest.timeoutInterval = TimeInterval(timeout.components.seconds)

        let (data, response) = try await session.upload(for: urlRequest, from: bodyData)
        return try processResponse(response, data: data, fallbackURL: urlRequest.url)
    }

    // MARK: - Private Helpers

    private func makeURLRequest(from request: HTTPRequest) throws -> URLRequest {
        guard let urlRequest = URLRequest(httpRequest: request) else {
            throw URLError(.badURL)
        }
        return urlRequest
    }

    private func processResponse(
        _ response: URLResponse,
        data: Data,
        fallbackURL: URL?
    ) throws -> (Data, HTTPResponse, URL) {
        guard let httpURLResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard let httpResponse = httpURLResponse.httpResponse else {
            throw URLError(.badServerResponse)
        }

        guard let url = httpURLResponse.url ?? fallbackURL else {
            throw URLError(.badURL)
        }

        return (data, httpResponse, url)
    }
}
