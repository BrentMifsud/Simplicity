//
//  DateDecodingStrategyTests.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-15.
//

import Foundation
import Testing

@Suite("Date Decoding Strategy Tests")
struct DateDecodingStrategyTests {
    
    private struct Container: Decodable {
        let date: Date
    }
    
    private func decodeDate(from json: String, using decoder: JSONDecoder) throws -> Date {
        let data = Data(json.utf8)
        return try decoder.decode(Container.self, from: data).date
    }
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601Long
        return decoder
    }
    
    @Test("decodes ISO8601 with milliseconds")
    func testDecodeMilliseconds() throws {
        let json = #"{ "date": "2025-10-15T12:34:56.789Z" }"#
        let date = try decodeDate(from: json, using: decoder)
        // Format date back to string with fractional seconds to check presence of milliseconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatted = formatter.string(from: date)
        // Assert milliseconds are present in the formatted string as .789 or similar
        #expect(formatted.contains(".789") || formatted.contains(".78"))
    }
    
    @Test("decodes ISO8601 with microseconds")
    func testDecodeMicroseconds() throws {
        let json = #"{ "date": "2025-10-15T12:34:56.789123Z" }"#
        _ = try decodeDate(from: json, using: decoder)
        // Success is no throw
    }
    
    @Test("decodes ISO8601 with timezone offset and matches UTC instant")
    func testDecodeTimezoneOffset() throws {
        let jsonUTC = #"{ "date": "2025-10-15T12:34:56.250000Z" }"#
        let jsonOffset = #"{ "date": "2025-10-15T14:34:56.250000+02:00" }"#
        let dateUTC = try decodeDate(from: jsonUTC, using: decoder)
        let dateOffset = try decodeDate(from: jsonOffset, using: decoder)
        let diff = abs(dateUTC.timeIntervalSince(dateOffset))
        #expect(diff == 0)
    }
    
    @Test("accepts two-digit fractional seconds")
    func testDecodeTwoDigitFractionalSeconds() throws {
        let json = #"{ "date": "2025-10-15T12:34:56.78Z" }"#
        _ = try decodeDate(from: json, using: decoder)
        // Success is no throw
    }
}
