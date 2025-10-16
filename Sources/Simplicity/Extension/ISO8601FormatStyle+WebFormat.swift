//
//  ISO8601FormatStyle+WebFormat.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-15.
//

public import Foundation

public extension Date.ISO8601FormatStyle {
    static let webFormat = Date.ISO8601FormatStyle()
        .year()
        .month()
        .day()
        .time(includingFractionalSeconds: true)
        .timeZone(separator: .omitted)
}
