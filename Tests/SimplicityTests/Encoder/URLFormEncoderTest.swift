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
}

