//
//  MultipartFormEncoderTest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-14.
//

import Foundation
@testable import Simplicity
import Testing

@Suite("MultipartFormEncoder tests")
struct MultipartFormEncoderTests {

    @Test("Init with random boundary produces non-empty, space-free boundary and contentType")
    func testInitRandomBoundary() throws {
        let encoder = try MultipartFormEncoder()
        #expect(encoder.boundary.isEmpty == false)
        #expect(encoder.boundary.contains(" ") == false)
        #expect(encoder.contentType == "multipart/form-data; boundary=\(encoder.boundary)")
    }

    @Test("Init with explicit valid boundary")
    func testInitWithExplicitBoundary() throws {
        let encoder = try MultipartFormEncoder(boundary: "BoundaryFixed123")
        #expect(encoder.boundary == "BoundaryFixed123")
        #expect(encoder.contentType == "multipart/form-data; boundary=BoundaryFixed123")
    }

    @Test("Init with invalid boundary throws .invalidBoundary")
    func testInitWithInvalidBoundary() {
        #expect(throws: MultipartFormEncoder.MultipartError.invalidBoundary) {
            _ = try MultipartFormEncoder(boundary: "")
        }
        #expect(throws: MultipartFormEncoder.MultipartError.invalidBoundary) {
            _ = try MultipartFormEncoder(boundary: "has space")
        }
    }

    @Test("Encode single text part includes headers, value, and closing boundary with CRLFs")
    func testEncodeSingleTextPart() throws {
        let encoder = try MultipartFormEncoder(boundary: "BoundaryXYZ")
        let parts: [MultipartFormEncoder.Part] = [
            .text(name: "field", value: "hello")
        ]
        let body = try encoder.encode(parts: parts)

        let bodyString = try #require(String(data: body, encoding: .utf8))
        let expectedPrefix = "--BoundaryXYZ\r\n"
        #expect(bodyString.hasPrefix(expectedPrefix))
        #expect(bodyString.contains("Content-Disposition: form-data; name=\"field\"\r\n"))
        #expect(bodyString.contains("\r\n\r\nhello\r\n"))
        #expect(bodyString.hasSuffix("--BoundaryXYZ--\r\n"))
    }

    @Test("Encode file part includes filename and content-type header")
    func testEncodeFilePart() throws {
        let encoder = try MultipartFormEncoder(boundary: "BoundaryFILE")
        let data = Data([0x01, 0x02, 0x03])
        let parts: [MultipartFormEncoder.Part] = [
            .file(name: "avatar", filename: "a.jpg", data: data, mimeType: "image/jpeg")
        ]
        let body = try encoder.encode(parts: parts)
        let bodyString = try #require(String(data: body, encoding: .utf8))

        #expect(bodyString.contains("Content-Disposition: form-data; name=\"avatar\"; filename=\"a.jpg\"\r\n"))
        #expect(bodyString.contains("Content-Type: image/jpeg\r\n"))
        // After headers there must be an empty line then data bytes then CRLF. The raw data won't be UTF-8 printable,
        // so we assert presence of the header structure and closing boundary, and verify total data length precisely.

        // Compute expected length: boundaries + headers + CRLFs + data length + closing boundary
        // Instead of reconstructing exact byte count, ensure the original data bytes are present in sequence.
        let raw = body
        // Find the data bytes sequence [0x01, 0x02, 0x03]
        if let range = raw.range(of: data) {
            #expect(range.count == data.count)
        } else {
            Issue.record("Encoded body does not contain raw file bytes in order.")
        }
        #expect(bodyString.hasSuffix("--BoundaryFILE--\r\n"))
    }

    @Test("Encode multiple parts preserves order and boundaries between them")
    func testEncodeMultiplePartsOrder() throws {
        let encoder = try MultipartFormEncoder(boundary: "BoundaryORDER")
        let parts: [MultipartFormEncoder.Part] = [
            .text(name: "first", value: "1"),
            .text(name: "second", value: "2")
        ]
        let body = try encoder.encode(parts: parts)
        let s = try #require(String(data: body, encoding: .utf8))

        let expected = "--BoundaryORDER\r\n" +
        "Content-Disposition: form-data; name=\"first\"\r\n" +
        "Content-Type: text/plain; charset=utf-8\r\n" +
        "\r\n" +
        "1\r\n" +
        "--BoundaryORDER\r\n" +
        "Content-Disposition: form-data; name=\"second\"\r\n" +
        "Content-Type: text/plain; charset=utf-8\r\n" +
        "\r\n" +
        "2\r\n" +
        "--BoundaryORDER--\r\n"

        #expect(s == expected)
    }

    @Test("Empty part name throws .emptyName")
    func testEmptyPartNameThrows() throws {
        let encoder = try MultipartFormEncoder(boundary: "BoundaryERR")
        let parts: [MultipartFormEncoder.Part] = [
            .text(name: "", value: "oops")
        ]
        #expect(throws: MultipartFormEncoder.MultipartError.emptyName) {
            _ = try encoder.encode(parts: parts)
        }
    }

    @Test("Max length enforcement throws for oversized matching part only")
    func testMaxLengthEnforcement() throws {
        let encoder = try MultipartFormEncoder(boundary: "BoundaryMAX")
        let small = Data(repeating: 0xAA, count: 4)
        let big = Data(repeating: 0xBB, count: 8)
        let parts: [MultipartFormEncoder.Part] = [
            .file(name: "avatar", filename: "a.bin", data: big, mimeType: nil),
            .file(name: "other", filename: "o.bin", data: big, mimeType: nil)
        ]

        // Enforce only for name "avatar" with max 4 -> should throw
        #expect(throws: MultipartFormEncoder.MultipartError.partExceedsMaxLength(partName: "avatar", limit: 4)) {
            _ = try encoder.encode(parts: parts, enforceMaxLengthFor: (name: "avatar", maxBytes: 4))
        }

        // If limit applies to other part, encoding should succeed
        let ok = try encoder.encode(parts: parts, enforceMaxLengthFor: (name: "other", maxBytes: 16))
        #expect(ok.count > 0)

        // No enforcement should also succeed
        let ok2 = try encoder.encode(parts: [.file(name: "avatar", filename: "a.bin", data: small)], enforceMaxLengthFor: nil)
        #expect(ok2.count > 0)
    }
}

