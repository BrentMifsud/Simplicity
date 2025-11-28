//
//  HTTPUploadRequest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-11-27.
//

public import struct Foundation.Data

public nonisolated protocol HTTPUploadRequest: HTTPRequest where RequestBody == Never {
    func encodeUploadData() throws -> Data
}
