// This file provides a mock URLProtocol for stubbing URLSession network requests for testing purposes.
import Foundation

private enum MockURLProtocolKeys {
    static let tokenHeader = "X-Mock-Token"
}

private final class _MockHandlerRegistry: @unchecked Sendable {
    static let shared = _MockHandlerRegistry()
    private var handlers: [String: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data?))] = [:]
    private let lock = NSLock()

    func set(handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data?), for token: String) {
        lock.lock()
        defer { lock.unlock() }
        handlers[token] = handler
    }

    func handler(for token: String) -> (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data?))? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[token]
    }

    func removeHandler(for token: String) {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeValue(forKey: token)
    }
}

class MockURLProtocol: URLProtocol, @unchecked Sendable {
    // Shared handler for controlling mock responses
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Prefer a token-specific handler if present, fall back to the default shared handler.
        let token = (request.allHTTPHeaderFields ?? [:])[MockURLProtocolKeys.tokenHeader]
        let handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data?))
        if let token, let tokenHandler = _MockHandlerRegistry.shared.handler(for: token) {
            handler = tokenHandler
        } else if let defaultHandler = Self.requestHandler {
            handler = defaultHandler
        } else {
            fatalError("Handler is not set.")
        }

        do {
            let (response, data) = try handler(request)
            // Return the response
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch let urlError as URLError {
            // Ensure URLError is properly passed as NSError in NSURLErrorDomain
            // This is required for watchOS to properly recognize the error
            let nsError = NSError(
                domain: NSURLErrorDomain,
                code: urlError.code.rawValue,
                userInfo: urlError.userInfo
            )
            client?.urlProtocol(self, didFailWithError: nsError)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // No-op
    }
}

extension MockURLProtocol {
    /// Register a handler for requests carrying the given token in the `X-Mock-Token` header.
    static func setHandler(_ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data?), forToken token: String) {
        _MockHandlerRegistry.shared.set(handler: handler, for: token)
    }

    /// Remove a previously registered token handler.
    static func removeHandler(forToken token: String) {
        _MockHandlerRegistry.shared.removeHandler(for: token)
    }
}
