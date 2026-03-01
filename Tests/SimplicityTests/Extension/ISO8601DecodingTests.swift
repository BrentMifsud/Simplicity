//
//  ISO8601DecodingTests.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-15.
//

import Foundation
import HTTPTypes
import Testing
@testable import Simplicity

@Suite("ISO8601 Date Decoding Tests")
struct ISO8601DecodingTests {
    private struct DateContainer: Codable, Sendable {
        let date: Date
    }

    private struct DateRequest: Request {
        typealias RequestBody = Never?
        typealias SuccessResponseBody = DateContainer
        typealias FailureResponseBody = Never

        static let operationID = "dateTest"
        var path: String { "/date" }
        var method: HTTPRequest.Method { .get }
        var headerFields: HTTPFields { HTTPFields() }
        var queryItems: [URLQueryItem] { [] }
    }

    private func decodeDate(from dateString: String) throws -> Date {
        let json = #"{"date":"\#(dateString)"}"#
        let result = try DateRequest().decodeSuccessBody(from: Data(json.utf8))
        return result.date
    }

    @Test("Decodes ISO8601 date strings with varying fractional second lengths", arguments: [
        "2025-10-15T12:34:56Z",
        "2025-10-15T12:34:56.0Z",
        "2025-10-15T12:34:56.7Z",
        "2025-10-15T12:34:56.78Z",
        "2025-10-15T12:34:56.789Z",
        "2025-10-15T12:34:56.7891Z",
        "2025-10-15T12:34:56.78912Z",
        "2025-10-15T12:34:56.789123Z",
        "2025-10-15T12:34:56.7891234Z",
        "2025-10-15T12:34:56.78912345Z",
        "2025-10-15T12:34:56.789123456Z",
        "2025-10-15T12:34:56.000Z",
        "2025-10-15T14:34:56.500+02:00",
    ])
    func decodesFractionalSeconds(dateString: String) throws {
        let date = try decodeDate(from: dateString)
        let components = Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: date)
        #expect(components.year == 2025)
        #expect(components.month == 10)
        #expect(components.day == 15)
        #expect(components.second == 56)
    }

    @Test("Timezone offset decodes to same instant as UTC")
    func decodesTimezoneOffset() throws {
        let utcDate = try decodeDate(from: "2025-10-15T12:34:56Z")
        let offsetDate = try decodeDate(from: "2025-10-15T14:34:56+02:00")
        #expect(abs(utcDate.timeIntervalSince(offsetDate)) < 0.001)
    }
}
