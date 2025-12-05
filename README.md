# Simplicity

[![Swift Package Tests](https://github.com/BrentMifsud/Simplicity/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/BrentMifsud/Simplicity/actions/workflows/ci.yaml)

A type-safe HTTP client library for Swift, inspired by [swift-openapi-generator](https://github.com/apple/swift-openapi-generator).

## Features

- Type-safe requests with associated `RequestBody`, `SuccessResponseBody`, and `FailureResponseBody` types
- Middleware chain for request/response interception (auth, logging, retries, etc.)
- Configurable cache policies with manual cache management
- File uploads with `HTTPUploadRequest`
- Built-in encoders for JSON, URL form, and multipart form data
- Full Swift 6 concurrency support with typed throws

## Requirements

- Swift 6.2+
- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+ / Mac Catalyst 17.0+ / visionOS 1.0+

## Installation

Add Simplicity to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/BrentMifsud/Simplicity.git", from: "1.0.0")
]
```

Then add `Simplicity` to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["Simplicity"]
)
```

## Usage

### Defining a Request

```swift
import Simplicity

struct LoginRequest: HTTPRequest {
    // Request body type
    struct Body: Encodable, Sendable {
        var username: String
        var password: String
    }

    // Response body types
    struct Success: Decodable, Sendable { var token: String }
    struct Failure: Decodable, Sendable { var error: String }

    // Associate the types with the HTTPRequest protocol
    typealias RequestBody = Body
    typealias SuccessResponseBody = Success
    typealias FailureResponseBody = Failure

    // Endpoint metadata
    static var operationID: String { "login" }
    var path: String { "/login" }
    var httpMethod: HTTPMethod { .post }
    var headers: [String: String] { ["Accept": "application/json"] }
    var queryItems: [URLQueryItem] { [] }

    // The actual body instance to send
    var httpBody: Body
}
```

### Sending Requests

```swift
let client = URLSessionHTTPClient(
    baseURL: URL(string: "https://api.example.com")!,
    middlewares: []
)

let response = try await client.send(
    request: LoginRequest(httpBody: .init(username: "user", password: "pass"))
)

// Decode the typed success or failure body on demand
if response.statusCode.isSuccess {
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
struct GetProfileRequest: HTTPRequest {
    typealias RequestBody = Never?
    typealias SuccessResponseBody = UserProfile
    typealias FailureResponseBody = APIError

    static var operationID: String { "getProfile" }
    var path: String { "/user/profile" }
    var httpMethod: HTTPMethod { .get }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
    var httpBody: Never? { nil }
}
```

## Middleware

Middleware intercepts requests and responses, enabling cross-cutting concerns like authentication, logging, retries, and caching.

The `Middleware.Request` tuple contains:

- `operationID: String` - Unique identifier for the operation
- `httpMethod: HTTPMethod` - The HTTP method
- `baseURL: URL` - Base URL for the request
- `path: String` - Request path
- `queryItems: [URLQueryItem]` - Query parameters
- `headers: [String: String]` - HTTP headers
- `httpBody: Data?` - Request body data
- `cachePolicy: CachePolicy` - Cache policy for the request

```swift
struct AuthMiddleware: Middleware {
    let tokenProvider: () -> String

    func intercept(
        request: Middleware.Request,
        next: nonisolated(nonsending) @Sendable (Middleware.Request) async throws -> Middleware.Response
    ) async throws -> Middleware.Response {
        var req = request
        req.headers["Authorization"] = "Bearer \(tokenProvider())"
        return try await next(req)
    }
}

struct LoggingMiddleware: Middleware {
    func intercept(
        request: Middleware.Request,
        next: nonisolated(nonsending) @Sendable (Middleware.Request) async throws -> Middleware.Response
    ) async throws -> Middleware.Response {
        print("Request: \(request.httpMethod) \(request.baseURL)\(request.path)")
        let response = try await next(request)
        print("Response: \(response.statusCode)")
        return response
    }
}

// Add middlewares to the client
let client = URLSessionHTTPClient(
    baseURL: baseURL,
    middlewares: [AuthMiddleware(tokenProvider: { token }), LoggingMiddleware()]
)
```

## Caching

### Cache Policies

Control caching behavior per-request using `CachePolicy`:

```swift
// Use server-provided cache directives (default)
let response = try await client.send(request: request, cachePolicy: .useProtocolCachePolicy)

// Return cached data if available, otherwise fetch from network
let response = try await client.send(request: request, cachePolicy: .returnCacheDataElseLoad)

// Only return cached data, never fetch (offline mode)
let response = try await client.send(request: request, cachePolicy: .returnCacheDataDontLoad)

// Always fetch fresh data, ignoring cache
let response = try await client.send(request: request, cachePolicy: .reloadIgnoringLocalCacheData)
```

### Manual Cache Management

The `HTTPClient` protocol provides methods for manual cache control:

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
let client = URLSessionHTTPClient(
    baseURL: baseURL,
    middlewares: [authMiddleware, cacheMiddleware]
)

// Manual cache operations via middleware
await cacheMiddleware.setCached(data, for: url)
await cacheMiddleware.removeCached(for: url)
await cacheMiddleware.clearCache()
```

## File Uploads

Use `HTTPUploadRequest` for file uploads:

```swift
struct UploadAvatarRequest: HTTPUploadRequest {
    typealias SuccessResponseBody = UploadResponse
    typealias FailureResponseBody = APIError

    static var operationID: String { "uploadAvatar" }
    var path: String { "/user/avatar" }
    var httpMethod: HTTPMethod { .post }
    var headers: [String: String] { ["Content-Type": "image/jpeg"] }
    var queryItems: [URLQueryItem] { [] }

    let imageData: Data

    func encodeUploadData() throws -> Data {
        imageData
    }
}

let response = try await client.upload(
    request: UploadAvatarRequest(imageData: imageData),
    timeout: .seconds(60)
)
```

## Encoders

### URL Form Encoding

For `application/x-www-form-urlencoded` requests:

```swift
struct FormLoginRequest: HTTPRequest {
    // ... type definitions ...

    func createURLRequest(baseURL: URL) -> URLRequest {
        formEncodedURLRequest(baseURL: baseURL)
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

var request = URLRequest(url: uploadURL)
request.httpMethod = "POST"
request.httpBody = body
request.setValue(encoder.contentType, forHTTPHeaderField: "Content-Type")
```

## License

MIT License. See [LICENSE](LICENSE) for details.
