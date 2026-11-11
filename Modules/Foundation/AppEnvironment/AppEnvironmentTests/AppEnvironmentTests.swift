//
//  AppEnvironmentTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import AppEnvironmentTestHelpers
import Foundation
import Testing

@MainActor
struct AppEnvironmentTests {
    @Test func defaultSessionKeepsNoCookies() {
        let configuration = AppEnvironment.defaultURLSession.configuration
        #expect(configuration.httpCookieAcceptPolicy == .never)
        #expect(configuration.httpShouldSetCookies == false)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.urlCache == nil)
    }

    @Test func environmentIdIsTheUserId() {
        #expect(AppEnvironment.test(userId: "alice").environmentId == "alice")
    }

    @Test func transientEnvironmentHasAReservedId() {
        let environment = AppEnvironment.test(userId: nil)
        #expect(environment.environmentId.hasPrefix("_"))
    }
}
