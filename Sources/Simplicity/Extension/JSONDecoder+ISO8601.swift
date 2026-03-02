//
//  JSONDecoder+ISO8601.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2026-03-01.
//

public import Foundation

extension JSONDecoder.DateDecodingStrategy {
    /// An ISO 8601 date decoding strategy that handles dates with or without fractional seconds.
    ///
    /// Unlike `.iso8601`, this strategy correctly parses dates with varying fractional second
    /// lengths (e.g., `.7Z`, `.789Z`, `.789123456Z`) across all supported platforms.
    public static let iso8601WithFractionalSeconds: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        // Try standard ISO 8601 (no fractional seconds)
        if let date = formatter.date(from: string) {
            return date
        }

        // Try with fractional seconds (normalize to 3 digits for ISO8601DateFormatter)
        if let normalized = normalizeFractionalSeconds(in: string) {
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected date string to be ISO8601-formatted."
            )
        )
    }

    /// Normalizes fractional seconds in an ISO 8601 string to exactly 3 digits.
    ///
    /// `ISO8601DateFormatter` with `.withFractionalSeconds` requires exactly 3 fractional digits.
    /// This helper pads or truncates any fractional part to 3 digits so the formatter can parse it.
    private static func normalizeFractionalSeconds(in dateString: String) -> String? {
        guard let dotIndex = dateString.firstIndex(of: ".") else {
            return nil
        }

        let afterDot = dateString.index(after: dotIndex)
        var endOfFraction = afterDot
        while endOfFraction < dateString.endIndex, dateString[endOfFraction].isWholeNumber {
            dateString.formIndex(after: &endOfFraction)
        }

        guard endOfFraction > afterDot else { return nil }

        let fractional = dateString[afterDot..<endOfFraction]
        let normalized: String
        if fractional.count >= 3 {
            normalized = String(fractional.prefix(3))
        } else {
            normalized = fractional + String(repeating: "0", count: 3 - fractional.count)
        }

        return dateString[..<dotIndex] + "." + normalized + dateString[endOfFraction...]
    }
}
