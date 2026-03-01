# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Workflow

- **Never commit directly to `main`.** All changes must be made on a feature branch and merged via pull request.
- Branch naming convention: `bm/<short-description>` (e.g., `bm/transport-protocol`, `bm/fix-cache-bug`)
- If you find yourself on `main`, create a feature branch before making any changes.

## Build and Test Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a specific test suite
swift test --filter MiddlewareTests

# Run a specific test
swift test --filter "MiddlewareTests/middlewareCallOrder"
```

## Architecture

Simplicity is a type-safe HTTP client library for Swift, inspired by swift-openapi-generator's client design. It uses Apple's `swift-http-types` (`HTTPTypes`, `HTTPTypesFoundation`) for standard HTTP primitives.

### Core Components

- **Client protocol** (`Sources/Simplicity/Protocol/Client.swift`): The main entry point. Defines `send(_:)` and `upload(_:)` methods that execute requests through a middleware chain. Uses Apple's `HTTPRequest.Method`, `HTTPResponse.Status`, and `HTTPFields` throughout.

- **Request protocol** (`Sources/Simplicity/Protocol/Request.swift`): Defines type-safe requests with associated `RequestBody`, `SuccessResponseBody`, and `FailureResponseBody` types. Uses Apple's `HTTPRequest.Method` and `HTTPFields` for properties. Provides default JSON encoding/decoding implementations. Use `Never?` for `RequestBody` on requests without a body.

- **Response struct** (`Sources/Simplicity/HTTP/Response.swift`): Wraps Apple's `HTTPResponse` and adds typed decoding via `decodeSuccessBody()` / `decodeFailureBody()`. Convenience accessors: `.status`, `.headerFields`.

- **Middleware protocol** (`Sources/Simplicity/Protocol/Middleware.swift`): Intercepts requests and responses via an `intercept` method that receives a `next` closure. Uses `MiddlewareRequest` and `MiddlewareResponse` structs that embed Apple's `HTTPRequest` and `HTTPResponse`.

- **Transport protocol** (`Sources/Simplicity/Protocol/Transport.swift`): Abstracts the network layer at the `HTTPRequest`/`HTTPResponse` level. `URLSessionTransport` is the default implementation wrapping `URLSession`; tests inject `MockTransport`.

- **URLSessionClient** (`Sources/Simplicity/Implementation/URLSessionClient.swift`): Concrete `Client` implementation. Delegates network calls to a `Transport` (defaults to `URLSessionTransport`). Accepts a `URLSession` convenience init for backward compatibility.

### HTTP Types

The library uses Apple's `swift-http-types` throughout:
- `HTTPRequest.Method` (extensible struct) instead of custom enum
- `HTTPResponse.Status` (supports any status code, `.kind` categorization) instead of custom enum
- `HTTPFields` (case-insensitive, multi-value, type-safe names) instead of `[String: String]`

### Request Body Handling

The `Request` protocol has special handling for bodyless requests:
- Use `Never?` as `RequestBody` and set `body` to `nil` for GET/DELETE requests
- The protocol has extensions that skip body encoding when `RequestBody` is `Never` or `Never?`

### Testing Approach

Tests use Swift Testing framework (`@Suite`, `@Test`, `#expect`). Network tests inject a `MockTransport` conforming to the `Transport` protocol — each test gets its own isolated handler closure with zero shared state.
- When running tests, be sure to run tests for all supported platforms
- Prefer `@Test(arguments:)` for parameterized tests over writing separate test functions for each input variation. One parameterized test with an array of inputs is cleaner than many near-identical test cases.

## Documentation Lookup (Context7)

When working on this project, **always use Context7** to look up documentation before relying on training data or web search. Use the `mcp__context7__resolve-library-id` and `mcp__context7__get-library-docs` tools.

Key libraries relevant to Simplicity:
- **Foundation** — `URLSession`, `URLRequest`, `URLCache`, `JSONEncoder`/`JSONDecoder` APIs
- **Swift Concurrency** — actors, `async`/`await`, `@Sendable`, `@concurrent`, `nonisolated`
- **Swift Testing** — `@Suite`, `@Test`, `#expect`, `#require`, `Issue.record`
