//
//  URLFormEncoderTest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-08-07.
//

import Simplicity
import Testing

@Suite("URLFormEncoder basic and edge cases")
struct URLFormEncoderTest {
    struct Simple: Encodable { let name: String; let age: Int; let isActive: Bool }
    struct Nested: Encodable { let user: Simple; let token: String }
    struct WithArray: Encodable { let tags: [String] }
    struct WithSpecials: Encodable { let key: String; let value: String }
    struct WithSpace: Encodable { let message: String }
    struct WithOptionals: Encodable { let required: String; let optional: String? }
    struct WithDictionary: Encodable { let dict: [String: String] }

    @Test("Encodes flat struct", arguments: [
        ("Alice", 30, true),
        ("Bob", 42, false),
        ("Carol", 22, true)
    ])
    func testFlatStruct(name: String, age: Int, isActive: Bool) async throws {
        let s = Simple(name: name, age: age, isActive: isActive)
        let data = try URLFormEncoder().encode(s)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("name=" + name))
        #expect(string.contains("age=" + String(age)))
        #expect(string.contains("isActive=" + String(isActive)))
    }

    @Test("Encodes nested struct", arguments: [
        ("Bob", 42, false, "ABC123"),
        ("Dana", 33, true, "ZZZ999"),
        ("Eve", 28, false, "T0K3N")
    ])
    func testNestedStruct(userName: String, userAge: Int, userActive: Bool, token: String) async throws {
        let n = Nested(user: .init(name: userName, age: userAge, isActive: userActive), token: token)
        let data = try URLFormEncoder().encode(n)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("user.name=" + userName))
        #expect(string.contains("user.age=" + String(userAge)))
        #expect(string.contains("user.isActive=" + String(userActive)))
        #expect(string.contains("token=" + token))
    }

    @Test("Encodes array property", arguments: [
        (["one", "two", "three"]),
        (["a", "b"]),
        ([])
    ])
    func testArray(tags: [String]) async throws {
        let arr = WithArray(tags: tags)
        let data = try URLFormEncoder().encode(arr)
        let string = String(data: data, encoding: .utf8)!
        for (i, tag) in tags.enumerated() {
            #expect(string.contains("tags." + String(i) + "=" + tag))
        }
        #expect(tags.isEmpty ? !string.contains("tags.0=") : true)
    }

    @Test("Percent-encodes reserved characters", arguments: [
        ("name&token", "hello=world&plus+sign", "name%26token", "hello%3Dworld%26plus%2Bsign"),
        ("has space", "slash/colon:", "has+space", "slash%2Fcolon%3A")
    ])
    func testPercentEncoding(key: String, value: String, expectedKey: String, expectedValue: String) async throws {
        let ws = WithSpecials(key: key, value: value)
        let data = try URLFormEncoder().encode(ws)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains(expectedKey))
        #expect(string.contains(expectedValue))
    }

    @Test("Encodes spaces as pluses", arguments: [
        ("hello world test", "hello+world+test"),
        ("a b c", "a+b+c"),
        ("lead space", "lead+space")
    ])
    func testSpaceEncoding(input: String, expected: String) async throws {
        let ws = WithSpace(message: input)
        let data = try URLFormEncoder().encode(ws)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains(expected))
    }

    @Test("Omits nil values", arguments: [
        ("foo", nil, "required=foo", false),
        ("bar", "baz", "optional=baz", true),
        ("xyz", nil, "required=xyz", false)
    ])
    func testOptionalOmitted(required: String, optional: String?, expectedSubstring: String, shouldContainOptional: Bool) async throws {
        let ws = WithOptionals(required: required, optional: optional)
        let data = try URLFormEncoder().encode(ws)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("required=" + required))
        if let optional = optional {
            #expect(string.contains("optional=" + optional))
        } else {
            #expect(!string.contains("optional"))
        }
    }
    
    @Test("Encodes dictionary property", arguments: [
        (["fruit": "apple", "color": "red"]),
        (["a": "1", "b": "2", "c": "3"]),
        ([:])
    ])
    func testDictionary(dict: [String: String]) async throws {
        let wd = WithDictionary(dict: dict)
        let data = try URLFormEncoder().encode(wd)
        let string = String(data: data, encoding: .utf8)!
        for (key, value) in dict {
            #expect(string.contains("dict." + key + "=" + value))
        }
        #expect(dict.isEmpty ? !string.contains("dict.") : true)
    }
    
    // Unicode and emoji characters
    @Test("Encodes unicode and emoji characters", arguments: [
        ("こんにちは", "世界🌏"),
        ("smile😊", "grinning😃"),
        ("emoji🔑", "value🔒")
    ])
    func testUnicodeAndEmoji(key: String, value: String) async throws {
        struct UnicodeStruct: Encodable { let key: String; let value: String }
        let s = UnicodeStruct(key: key, value: value)
        let data = try URLFormEncoder().encode(s)
        let string = String(data: data, encoding: .utf8)!
        
        // Parse form string into dictionary with percent decoding and plus-space replacement
        var dict = [String: String]()
        for pair in string.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            let rawKey = parts[0].replacingOccurrences(of: "+", with: " ")
            let decodedKey = rawKey.removingPercentEncoding ?? String(rawKey)
            let rawValue = parts.count == 2 ? parts[1] : Substring("")
            let decodedValue = rawValue.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(rawValue)
            dict[decodedKey] = decodedValue
        }
        #expect(dict["key"] == key)
        #expect(dict["value"] == value)
    }

    // Deeply nested structures
    struct DeepNested: Encodable { let lvl1: Lvl1 }; struct Lvl1: Encodable { let lvl2: Lvl2 }; struct Lvl2: Encodable { let lvl3: String }
    @Test("Encodes deeply nested structures", arguments: [ ("finalValue"), ("") ])
    func testDeeplyNested(final: String) async throws {
        let d = DeepNested(lvl1: .init(lvl2: .init(lvl3: final)))
        let data = try URLFormEncoder().encode(d)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("lvl1.lvl2.lvl3=" + final))
    }

    // Large strings
    @Test("Encodes long string values", arguments: [
        (String(repeating: "a", count: 1024)),
        (String(repeating: "x", count: 4096))
    ])
    func testLargeStringValues(value: String) async throws {
        struct LargeStringStruct: Encodable { let value: String }
        let s = LargeStringStruct(value: value)
        let data = try URLFormEncoder().encode(s)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("value=" + value))
    }

    // Explicitly empty dictionary and struct
    @Test("Encodes empty dictionary")
    func testEmptyDictionary() async throws {
        struct EmptyDictStruct: Encodable { let dict: [String: String] }
        let s = EmptyDictStruct(dict: [:])
        let data = try URLFormEncoder().encode(s)
        let string = String(data: data, encoding: .utf8)!
        #expect(!string.contains("dict."))
    }
    @Test("Encodes empty struct")
    func testEmptyStruct() async throws {
        struct EmptyStruct: Encodable {}
        let s = EmptyStruct()
        let data = try URLFormEncoder().encode(s)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.isEmpty)
    }

    // Arrays of nested objects
    struct ArrayNested: Encodable { let items: [Simple] }
    @Test("Encodes array of nested objects", arguments: [
        (["a", "b"]),
        (["x"]),
        ([])
    ])
    func testArrayOfNestedObjects(names: [String]) async throws {
        let simps = names.map { Simple(name: $0, age: 1, isActive: true) }
        let an = ArrayNested(items: simps)
        let data = try URLFormEncoder().encode(an)
        let string = String(data: data, encoding: .utf8)!
        for (i, name) in names.enumerated() {
            #expect(string.contains("items." + String(i) + ".name=" + name))
        }
    }

    // Multiple empty or whitespace-only strings
    @Test("Encodes empty and whitespace-only strings", arguments: [
        ("", " "),
        ("\t", "\n")
    ])
    func testEmptyAndWhitespaceStrings(a: String, b: String) async throws {
        struct EmptyWhite: Encodable { let a: String; let b: String }
        let s = EmptyWhite(a: a, b: b)
        let data = try URLFormEncoder().encode(s)
        let string = String(data: data, encoding: .utf8)!

        // Parse form string into dictionary with percent decoding and plus-space replacement
        var dict = [String: String]()
        for pair in string.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            let rawKey = parts[0].replacingOccurrences(of: "+", with: " ")
            let decodedKey = rawKey.removingPercentEncoding ?? String(rawKey)
            let rawValue = parts.count == 2 ? parts[1] : Substring("")
            let decodedValue = rawValue.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(rawValue)
            dict[decodedKey] = decodedValue
        }
        #expect(dict["a"] == a)
        #expect(dict["b"] == b)
    }
}

