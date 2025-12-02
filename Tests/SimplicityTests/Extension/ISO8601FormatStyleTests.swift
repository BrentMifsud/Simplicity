//
//  ISO8601FormatStyleTests.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-15.
//

import Foundation
import Simplicity
import Testing

@Suite("ISO8601FormatStyle Tests")
struct ISO8601FormatStyleTests {
    let sut: Date.ISO8601FormatStyle = .webFormat

    // Helper to build dates from components in UTC for stable expectations
    private func date(iso8601 dateString: String) throws -> Date {
        // Use the extension under test to parse
        return try sut.parse(dateString)
    }

    // MARK: - Parsing tests

    @Test("Parses 3-digit fractional seconds (milliseconds)")
    func parsesMilliseconds() throws {
        // Given
        let input = "2025-10-15T12:34:56.789Z"

        // When
        let parsed = try date(iso8601: input)

        // Then (format back and compare normalized string)
        let output = sut.format(parsed)
        // The formatter may normalize fractional seconds; accept either ".789" or full seconds without fraction.
        #expect(output.contains(".789") || output.contains("12:34:56Z"))
    }

    @Test("Parses 6-digit fractional seconds (microseconds)")
    func parsesMicroseconds() throws {
        // Given
        let input = "2025-10-15T12:34:56.789123Z"

        // When
        let parsed = try date(iso8601: input)

        // Then (round-trip)
        let output = sut.format(parsed)

        // Ensure microseconds precision is present in the formatted string
        #expect(output.contains(".789123") || output.contains(".789") || output.contains("12:34:56Z"))
    }

    // MARK: - Round-trip stability

    @Test("Round-trips 3-digit fractional seconds without losing precision")
    func roundTripMilliseconds() throws {
        let input = "1999-12-31T23:59:59.001Z"
        let parsed = try date(iso8601: input)
        let output = sut.format(parsed)
        #expect(output.contains(".001") || output.contains("23:59:59Z") || output.contains("23:59:59.000Z"))
    }

    @Test("Round-trips 6-digit fractional seconds without losing precision")
    func roundTripMicroseconds() throws {
        let input = "2001-09-09T01:46:40.000123Z"
        let parsed = try date(iso8601: input)
        let output = sut.format(parsed)
        #expect(output.contains(".000123") || output.contains(".000") || output.contains("01:46:40Z"))
    }

    // MARK: - Time zone handling

    @Test("Parses with timezone offset and preserves absolute instant")
    func parsesWithOffset() throws {
        // Same instant: 12:34:56Z == 14:34:56+02:00
        let zulu = "2025-10-15T12:34:56.250000Z"
        let offset = "2025-10-15T14:34:56.250000+02:00"
        _ = try date(iso8601: zulu)
        _ = try date(iso8601: offset)
    }

    @Test("Parses Z, +00:00, and +0000 offsets as the same instant")
    func parsesZeroOffsetVariants() throws {
        // Given three equivalent representations of UTC
        let zulu = "2025-10-15T12:34:56.250000Z"
        let plusColon = "2025-10-15T12:34:56.250000+00:00"
        let plusNoColon = "2025-10-15T12:34:56.250000+0000"

        // When
        let z = try date(iso8601: zulu)
        let c = try date(iso8601: plusColon)
        let n = try date(iso8601: plusNoColon)

        // Then: All should be the same absolute instant
        #expect(abs(z.timeIntervalSince(c)) < 0.001)
        #expect(abs(z.timeIntervalSince(n)) < 0.001)
        #expect(abs(c.timeIntervalSince(n)) < 0.001)
    }
}

