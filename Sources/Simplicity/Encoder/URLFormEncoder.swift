//
//  URLFormEncoder.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-08-07.
//

import Foundation

/// Encodes Encodable types into `application/x-www-form-urlencoded` data.
public struct URLFormEncoder {
    public init() {}
    
    /// Encodes the given Encodable value as `application/x-www-form-urlencoded` data.
    /// - Parameter value: The value to encode.
    /// - Returns: The data representing the form-encoded object.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let dictionary = try flatten(value)
        let components = dictionary.map { key, value in
            "\(percentEncode(key))=\(percentEncode(value))"
        }
        let formString = components.joined(separator: "&")
        guard let data = formString.data(using: .utf8) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Failed to encode form string as UTF-8."))
        }
        return data
    }
    
    /// Flattens an Encodable value into a [String: String] dictionary.
    private func flatten<T: Encodable>(_ value: T) throws -> [String: String] {
        let encoder = _FormEncoder()
        try value.encode(to: encoder)
        return encoder.values
    }
    
    /// Percent-encodes a string for use in x-www-form-urlencoded data.
    private func percentEncode(_ string: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._*")
        return string.addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: "%20", with: "+") ?? string
    }
}

// Internal Encoder
private class _FormEncoder: Encoder {
    var values: [String: String] = [:]
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = KeyedContainer<Key>(encoder: self)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedContainer(encoder: self)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        SingleValueContainer(encoder: self)
    }
    
    // MARK: - Containers
    private struct KeyedContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
        let encoder: _FormEncoder
        var codingPath: [CodingKey] { encoder.codingPath }
        
        mutating func encodeNil(forKey key: K) throws {}
        mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws {
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            try value.encode(to: encoder)
        }
        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> {
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            let container = KeyedContainer<NestedKey>(encoder: encoder)
            return KeyedEncodingContainer(container)
        }
        mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            return UnkeyedContainer(encoder: encoder)
        }
        mutating func superEncoder() -> Encoder { encoder }
        mutating func superEncoder(forKey key: K) -> Encoder { encoder }
    }
    
    private struct UnkeyedContainer: UnkeyedEncodingContainer {
        let encoder: _FormEncoder
        var codingPath: [CodingKey] { encoder.codingPath }
        var count: Int = 0
        
        mutating func encodeNil() throws {}
        mutating func encode<T: Encodable>(_ value: T) throws {
            let key = CodingKeyIndex(intValue: count)
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            try value.encode(to: encoder)
            count += 1
        }
        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
            let key = CodingKeyIndex(intValue: count)
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            let container = KeyedContainer<NestedKey>(encoder: encoder)
            count += 1
            return KeyedEncodingContainer(container)
        }
        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let key = CodingKeyIndex(intValue: count)
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            count += 1
            return UnkeyedContainer(encoder: encoder)
        }
        mutating func superEncoder() -> Encoder { encoder }
    }
    
    private struct SingleValueContainer: SingleValueEncodingContainer {
        let encoder: _FormEncoder
        var codingPath: [CodingKey] { encoder.codingPath }
        
        mutating func encodeNil() throws {}
        mutating func encode<T: Encodable>(_ value: T) throws {
            let key = encoder.codingPath.map { $0.stringValue }.joined(separator: "[")
            let finalKey = key.replacingOccurrences(of: "[", with: ".")
            encoder.values[finalKey] = "\(value)"
        }
    }

    // Helper for unkeyed container
    private struct CodingKeyIndex: CodingKey {
        var intValue: Int?
        var stringValue: String { intValue.map(String.init) ?? "" }
        init(intValue: Int) { self.intValue = intValue }
        init?(stringValue: String) { self.intValue = Int(stringValue) }
    }
}
