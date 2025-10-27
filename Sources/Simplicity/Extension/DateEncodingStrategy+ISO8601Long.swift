//
//  DateEncodingStrategy+ISO8601Long.swift
//  Simplicity
//
//  Created by OpenAI on 2025-10-20.
//

public import Foundation

public extension JSONEncoder.DateEncodingStrategy {
    static let iso8601Long: Self = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        let formatStyle = Date.ISO8601FormatStyle.webFormat
        try container.encode(date.formatted(formatStyle))
    }
}
