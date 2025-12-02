# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Simplicity is a type-safe HTTP client library for Swift, inspired by swift-openapi-generator's client design.

### Core Components

- **HTTPClient** (`Sources/Simplicity/HTTPClient.swift`): The main entry point. Executes requests through a middleware chain using `URLSession`. The `send(request:)` method builds the middleware chain in reverse order, so middlewares execute in the order they were added.

- **HTTPRequest protocol** (`Sources/Simplicity/Protocol/HTTPRequest.swift`): Defines type-safe requests with associated `RequestBody` and `ResponseBody` types. Provides default JSON encoding/decoding implementations. Use `Never?` for `RequestBody` on requests without a body.

- **Middleware protocol** (`Sources/Simplicity/Protocol/Middleware.swift`): Intercepts requests and responses via an `intercept` method that receives a `next` closure. Middlewares can modify requests before calling `next` and inspect/modify responses after.

### Request Body Handling

The `HTTPRequest` protocol has special handling for bodyless requests:
- Use `Never?` as `RequestBody` and set `httpBody` to `nil` for GET/DELETE requests
- The protocol has private extensions that skip body encoding when `RequestBody` is `Never` or `Never?`

### Testing Approach

Tests use Swift Testing framework (`@Suite`, `@Test`, `#expect`). Network tests mock `URLSession` via `MockURLProtocol` configured on an ephemeral session configuration.
