# Simplicity

[![Swift Package Tests](https://github.com/BrentMifsud/Simplicity/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/BrentMifsud/Simplicity/actions/workflows/ci.yaml)

A type-safe HTTP client library for Swift, inspired by [swift-openapi-generator](https://github.com/apple/swift-openapi-generator). Built on Apple's [swift-http-types](https://github.com/apple/swift-http-types) for interoperability with the broader Swift HTTP ecosystem.

## Features

- Type-safe requests with associated `RequestBody`, `SuccessResponseBody`, and `FailureResponseBody` types
- Built on Apple's `swift-http-types` — uses `HTTPRequest.Method`, `HTTPResponse.Status`, and `HTTPFields` throughout
- Middleware chain for request/response interception (auth, logging, retries, etc.)
- Configurable cache policies with manual cache management
- File uploads with `UploadRequest`
- Built-in encoders for JSON, URL form, and multipart form data
- Full Swift 6 concurrency support with typed throws

## Requirements

- Swift 6.2+
- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+ / Mac Catalyst 17.0+ / visionOS 1.0+

## Installation

Add Simplicity to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/BrentMifsud/Simplicity.git", from: "2.0.0")
]
```

Then add `Simplicity` to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["Simplicity"]
)
```

> **Note:** You do not need to add `swift-http-types` as a separate dependency. Simplicity re-exports
> the `HTTPTypes` module, so types like `HTTPRequest.Method`, `HTTPResponse.Status`, and `HTTPFields`
> are available directly via `import Simplicity`.

## Usage

### Defining a Request

```swift
import Simplicity

struct LoginRequest: Request {
    // Request body type
    struct Body: Encodable, Sendable {
        var username: String
        var password: String
    }

    // Response body types
    struct Success: Decodable, Sendable { var token: String }
    struct Failure: Decodable, Sendable { var error: String }

    // Associate the types with the Request protocol
    typealias RequestBody = Body
    typealias SuccessResponseBody = Success
    typealias FailureResponseBody = Failure

    // Endpoint metadata
    static var operationID: String { "login" }
    var path: String { "/login" }
    var method: HTTPRequest.Method { .post }
    var headerFields: HTTPFields { [.contentType: "application/json"] }
    var queryItems: [URLQueryItem] { [] }

    // The actual body instance to send
    var body: Body
}
```

### Sending Requests

```swift
let client = URLSessionClient(
    baseURL: URL(string: "https://api.example.com")!,
    middlewares: []
)

let response = try await client.send(
    LoginRequest(body: .init(username: "user", password: "pass"))
)

// Decode the typed success or failure body on demand
if response.status.kind == .successful {
    let model = try response.decodeSuccessBody()
    print(model.token)
} else {
    let failure = try response.decodeFailureBody()
    print(failure.error)
}
```

### Requests Without a Body

Use `Never?` as `RequestBody` for GET/DELETE requests:

```swift
struct GetProfileRequest: Request {
    typealias RequestBody = Never?
    typealias SuccessResponseBody = UserProfile
    typealias FailureResponseBody = APIError

    static var operationID: String { "getProfile" }
    var path: String { "/user/profile" }
    var method: HTTPRequest.Method { .get }
    var headerFields: HTTPFields { HTTPFields() }
    var queryItems: [URLQueryItem] { [] }
    var body: Never? { nil }
}
```

## Middleware

Middleware intercepts requests and responses, enabling cross-cutting concerns like authentication, logging, retries, and caching.

Middleware operates on `MiddlewareRequest` and `MiddlewareResponse` structs that embed Apple's `HTTPRequest` and `HTTPResponse` types:

**`MiddlewareRequest`** contains:

- `httpRequest: HTTPRequest` — Apple's type (method, URL components, header fields)
- `body: Data?` — Request body data
- `operationID: String` — Unique identifier for the operation
- `baseURL: URL` — Base URL for the request
- `cachePolicy: CachePolicy` — Cache policy for the request
- `url: URL` — Computed full request URL

**`MiddlewareResponse`** contains:

- `httpResponse: HTTPResponse` — Apple's type (status, header fields)
- `url: URL` — Final response URL
- `body: Data` — Response body data

```swift
struct AuthMiddleware: Middleware {
    let tokenProvider: () -> String

    func intercept(
        request: MiddlewareRequest,
        next: nonisolated(nonsending) @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse
    ) async throws -> MiddlewareResponse {
        var req = request
        req.httpRequest.headerFields[.authorization] = "Bearer \(tokenProvider())"
        return try await next(req)
    }
}

struct LoggingMiddleware: Middleware {
    func intercept(
        request: MiddlewareRequest,
        next: nonisolated(nonsending) @Sendable (MiddlewareRequest) async throws -> MiddlewareResponse
    ) async throws -> MiddlewareResponse {
        print("Request: \(request.httpRequest.method) \(request.url)")
        let response = try await next(request)
        print("Response: \(response.httpResponse.status)")
        return response
    }
}

// Add middlewares to the client
let client = URLSessionClient(
    baseURL: baseURL,
    middlewares: [AuthMiddleware(tokenProvider: { token }), LoggingMiddleware()]
)
```

## Caching

### Cache Policies

Control caching behavior per-request using `CachePolicy`:

```swift
// Use server-provided cache directives (default)
let response = try await client.send(request, cachePolicy: .useProtocolCachePolicy)

// Return cached data if available, otherwise fetch from network
let response = try await client.send(request, cachePolicy: .returnCacheDataElseLoad)

// Only return cached data, never fetch (offline mode)
let response = try await client.send(request, cachePolicy: .returnCacheDataDontLoad)

// Always fetch fresh data, ignoring cache
let response = try await client.send(request, cachePolicy: .reloadIgnoringLocalCacheData)
```

### Manual Cache Management

The `Client` protocol provides methods for manual cache control:

```swift
// Store a response in the cache
try await client.setCachedResponse(subscriptions, for: GetSubscriptionsRequest())

// Retrieve a cached response
let cached = try await client.cachedResponse(for: GetSubscriptionsRequest())

// Remove a cached response
await client.removeCachedResponse(for: GetSubscriptionsRequest())

// Clear all cached responses
await client.clearNetworkCache()
```

### CacheMiddleware

For more control over caching (especially with authenticated requests), use `CacheMiddleware`:

```swift
let cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 50_000_000)
let cacheMiddleware = CacheMiddleware(urlCache: cache)

// Place after auth middleware so cache keys include the final URL
let client = URLSessionClient(
    baseURL: baseURL,
    middlewares: [authMiddleware, cacheMiddleware]
)

// Manual cache operations via middleware
await cacheMiddleware.setCached(data, for: url)
await cacheMiddleware.removeCached(for: url)
await cacheMiddleware.clearCache()
```

## File Uploads

Use `UploadRequest` for file uploads:

```swift
struct UploadAvatarRequest: UploadRequest {
    typealias SuccessResponseBody = UploadResponse
    typealias FailureResponseBody = APIError

    static var operationID: String { "uploadAvatar" }
    var path: String { "/user/avatar" }
    var method: HTTPRequest.Method { .post }
    var headerFields: HTTPFields { [.contentType: "image/jpeg"] }
    var queryItems: [URLQueryItem] { [] }

    let imageData: Data

    func encodeUploadData() throws -> Data {
        imageData
    }
}

let response = try await client.upload(
    UploadAvatarRequest(imageData: imageData),
    timeout: .seconds(60)
)
```

## Encoders

### URL Form Encoding

For `application/x-www-form-urlencoded` requests, override `encodeBody()`:

```swift
struct FormLoginRequest: Request {
    typealias RequestBody = Credentials
    typealias SuccessResponseBody = AuthToken
    typealias FailureResponseBody = APIError

    static var operationID: String { "formLogin" }
    var path: String { "/login" }
    var method: HTTPRequest.Method { .post }
    var headerFields: HTTPFields { [.contentType: "application/x-www-form-urlencoded"] }
    var queryItems: [URLQueryItem] { [] }

    var body: Credentials

    func encodeBody() throws -> Data? {
        try URLFormEncoder().encode(body)
    }
}
```

Or use `URLFormEncoder` directly:

```swift
let encoder = URLFormEncoder()
let data = try encoder.encode(MyFormData(field1: "value1", field2: "value2"))
```

### Multipart Form Data

For file uploads with additional fields:

```swift
let encoder = try MultipartFormEncoder()
let parts: [MultipartFormEncoder.Part] = [
    .text(name: "description", value: "Profile photo"),
    .file(name: "avatar", filename: "photo.jpg", data: imageData, mimeType: "image/jpeg")
]
let body = try encoder.encode(parts: parts)
```

## Migration from 1.x

If you're upgrading from Simplicity 1.x, here's a summary of the API changes:

### Type Renames

| 1.x | 2.x | Reason |
|-----|-----|--------|
| `HTTPClient` | `Client` | Avoids conflict with other libraries; module-scoped as `Simplicity.Client` |
| `HTTPRequest` (protocol) | `Request` | Conflicts with `HTTPTypes.HTTPRequest` struct |
| `HTTPUploadRequest` | `UploadRequest` | Consistent naming |
| `HTTPResponse<S,F>` | `Response<S,F>` | Conflicts with `HTTPTypes.HTTPResponse` struct |
| `URLSessionHTTPClient` | `URLSessionClient` | Consistent naming |
| `HTTPMethod` (enum) | `HTTPRequest.Method` | Apple's extensible struct from `swift-http-types` |
| `HTTPStatusCode` (enum) | `HTTPResponse.Status` | Apple's type with `.kind` categorization |

### Property Renames

| 1.x | 2.x |
|-----|-----|
| `httpMethod` | `method` |
| `headers: [String: String]` | `headerFields: HTTPFields` |
| `httpBody` | `body` |
| `statusCode` | `status` |
| `encodeHTTPBody()` | `encodeBody()` |
| `createURLRequest(baseURL:)` | `makeHTTPRequest(baseURL:)` |
| `decodeSuccessResponseData(_:)` | `decodeSuccessBody(from:)` |
| `decodeFailureResponseData(_:)` | `decodeFailureBody(from:)` |
| `send(request:)` | `send(_:)` |
| `upload(request:)` | `upload(_:)` |
| `statusCode.isSuccess` | `status.kind == .successful` |

### Middleware Changes

Middleware request/response changed from named tuples to structs wrapping Apple's types:

```swift
// 1.x — tuple fields accessed directly
req.headers["Authorization"] = "Bearer ..."
print(response.statusCode)

// 2.x — Apple types accessed through embedded structs
req.httpRequest.headerFields[.authorization] = "Bearer ..."
print(response.httpResponse.status)
```

## License

MIT License. See [LICENSE](LICENSE) for details.
