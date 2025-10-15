//
//  MultipartFormEncoder.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-14.
//

public import Foundation

/// A lightweight encoder for building `multipart/form-data` request bodies.
///
/// Example (uploading an avatar image under the field name "avatar"):
/// ```swift
/// let encoder = MultipartFormEncoder()
/// let imageData = try Data(contentsOf: imageURL)
/// let parts: [MultipartFormEncoder.Part] = [
///     .file(name: "avatar", filename: "avatar.jpg", data: imageData, mimeType: "image/jpeg")
/// ]
/// let body = try encoder.encode(parts: parts)
/// var request = URLRequest(url: uploadURL)
/// request.httpMethod = "POST"
/// request.httpBody = body
/// request.setValue(encoder.contentType, forHTTPHeaderField: "Content-Type")
/// ```
public struct MultipartFormEncoder {
    /// Errors that can occur during multipart encoding.
    public enum MultipartError: Error, LocalizedError, Equatable {
        case emptyName
        case invalidBoundary
        case partExceedsMaxLength(partName: String, limit: Int)

        public var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Multipart part name must not be empty."
            case .invalidBoundary:
                return "Boundary must not be empty and must not contain spaces."
            case let .partExceedsMaxLength(partName, limit):
                return "Part \(partName) exceeds the maximum allowed length of \(limit) bytes."
            }
        }
    }

    /// A single multipart/form-data part.
    public struct Part {
        public let name: String
        public let filename: String?
        public let mimeType: String?
        public let data: Data

        public init(name: String, filename: String? = nil, mimeType: String? = nil, data: Data) {
            self.name = name
            self.filename = filename
            self.mimeType = mimeType
            self.data = data
        }

        /// Creates a simple text field part.
        public static func text(name: String, value: String, encoding: String.Encoding = .utf8) -> Part {
            Part(name: name, filename: nil, mimeType: "text/plain; charset=\(encoding.ianaCharset)", data: Data(value.utf8))
        }

        /// Creates a binary/file field part.
        /// - Parameters:
        ///   - name: Field name.
        ///   - filename: Suggested filename for the server.
        ///   - data: File data.
        ///   - mimeType: Content type (defaults to application/octet-stream if nil).
        public static func file(name: String, filename: String, data: Data, mimeType: String? = nil) -> Part {
            Part(name: name, filename: filename, mimeType: mimeType, data: data)
        }
    }

    /// The boundary that separates parts. Must be unique and free of spaces.
    public let boundary: String

    /// The value to use for the `Content-Type` header.
    public var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    /// Create a new encoder.
    /// - Parameter boundary: Optional explicit boundary. If nil, a safe random boundary is generated.
    public init(boundary: String? = nil) throws {
        if let boundary, boundary.isEmpty == false, boundary.contains(" ") == false {
            self.boundary = boundary
        } else if boundary == nil {
            self.boundary = "Boundary-" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        } else {
            throw MultipartError.invalidBoundary
        }
    }

    /// Encode an array of parts into a single `multipart/form-data` body.
    /// - Parameters:
    ///   - parts: The parts to encode.
    ///   - enforceMaxLengthFor: Optional tuple to enforce a maximum byte length for a single named part (e.g., (name: "avatar", maxBytes: 10240)).
    /// - Returns: Encoded body `Data` suitable for `URLRequest.httpBody`.
    public func encode(parts: [Part], enforceMaxLengthFor: (name: String, maxBytes: Int)? = nil) throws -> Data {
        var body = Data()
        let crlf = "\r\n"
        let boundaryPrefix = "--" + boundary + crlf

        for part in parts {
            guard part.name.isEmpty == false else { throw MultipartError.emptyName }
            if let rule = enforceMaxLengthFor, rule.name == part.name, part.data.count > rule.maxBytes {
                throw MultipartError.partExceedsMaxLength(partName: part.name, limit: rule.maxBytes)
            }

            // --boundary\r\n
            body.append(Data(boundaryPrefix.utf8))

            // Content-Disposition
            if let filename = part.filename {
                let disposition = "Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"" + crlf
                body.append(Data(disposition.utf8))
                let type = "Content-Type: \(part.mimeType ?? "application/octet-stream")" + crlf
                body.append(Data(type.utf8))
            } else {
                let disposition = "Content-Disposition: form-data; name=\"\(part.name)\"" + crlf
                body.append(Data(disposition.utf8))
                if let mime = part.mimeType {
                    let type = "Content-Type: \(mime)" + crlf
                    body.append(Data(type.utf8))
                }
            }

            // Empty line between headers and data
            body.append(Data(crlf.utf8))

            // Data
            body.append(part.data)
            body.append(Data(crlf.utf8))
        }

        // Closing boundary
        let closing = "--" + boundary + "--" + crlf
        body.append(Data(closing.utf8))

        return body
    }
}

private extension String.Encoding {
    /// Best-effort mapping to IANA charset names for Content-Type headers.
    var ianaCharset: String {
        switch self {
        case .utf8: return "utf-8"
        case .utf16: return "utf-16"
        case .utf16LittleEndian: return "utf-16le"
        case .utf16BigEndian: return "utf-16be"
        case .utf32: return "utf-32"
        case .utf32LittleEndian: return "utf-32le"
        case .utf32BigEndian: return "utf-32be"
        default: return "utf-8"
        }
    }
}

#if DEBUG
/// Example helper showing how to build a URLRequest for the avatar upload scenario.
public func makeAvatarUploadRequest(to url: URL, imageData: Data) throws -> URLRequest {
    let encoder = try MultipartFormEncoder()
    let parts: [MultipartFormEncoder.Part] = [
        .file(name: "avatar", filename: "avatar.jpg", data: imageData, mimeType: "application/octet-stream")
    ]
    let body = try encoder.encode(parts: parts, enforceMaxLengthFor: (name: "avatar", maxBytes: 10_240))

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue(encoder.contentType, forHTTPHeaderField: "Content-Type")
    return request
}
#endif
