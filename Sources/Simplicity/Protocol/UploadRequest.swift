//
//  UploadRequest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-11-27.
//

public import struct Foundation.Data

public nonisolated protocol UploadRequest: Request where RequestBody == Never {
    func encodeUploadData() throws -> Data
}
