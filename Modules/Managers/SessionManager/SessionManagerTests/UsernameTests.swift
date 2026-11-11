//
//  UsernameTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import SessionManager
import Testing

struct UsernameTests {
    @Test func trimsAndLowercases() {
        #expect(Username("  Alice ")?.rawValue == "alice")
    }

    @Test(arguments: ["a", "alice", "a-b_c", "9lives", String(repeating: "x", count: 32)])
    func acceptsValidNames(_ text: String) {
        #expect(Username(text) != nil)
    }

    @Test(arguments: ["", "   ", "_transient_", "-dash", "has space", "émile", "a.b", String(repeating: "x", count: 33)])
    func rejectsInvalidNames(_ text: String) {
        #expect(Username(text) == nil)
    }
}
