//
//  DateDecodingStrategy+ISO8601Long.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-15.
//

public import Foundation

public extension JSONDecoder.DateDecodingStrategy {
    static let iso8601Long: Self = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        let formatStyle = Date.ISO8601FormatStyle.webFormat
        guard let date = try? Date(dateString, strategy: formatStyle) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }

        return date
    }
}
