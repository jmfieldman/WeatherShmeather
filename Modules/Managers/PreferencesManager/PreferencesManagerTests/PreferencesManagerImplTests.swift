//
//  PreferencesManagerImplTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import AppEnvironmentTestHelpers
import Foundation
import Inject
import PreferencesManager
import PreferencesManagerImpl
import PreferencesManagerTestHelpers
import SwiftAsyncEx
import Testing

@MainActor
struct PreferencesManagerImplTests {
    private func makeManager(
        _ measurementSystem: Locale.MeasurementSystem = .us,
        store: PersistentPropertyStorageEngine = InMemoryStorageEngine(),
    ) -> PreferencesManagerImpl {
        let environment = AppEnvironment.test(propertyFileStore: store)
        InjectionManager.register(AppEnvironment.self) { environment }
        InjectionManager.resetCurrentContainer()
        return PreferencesManagerImpl(measurementSystem: measurementSystem)
    }

    @Test func defaultsFollowTheRegion() {
        let us = makeManager(.us).unitSettings.value
        #expect(us.temperature == .fahrenheit)
        #expect(us.windSpeed == .milesPerHour)
        #expect(us.precipitation == .inches)

        let metric = makeManager(.metric).unitSettings.value
        #expect(metric.temperature == .celsius)
        #expect(metric.windSpeed == .kilometersPerHour)
        #expect(metric.airQualityScale == .european)
    }

    @Test func systemTemperatureResolvesForTheRegion() async {
        let manager = makeManager(.us)
        #expect(manager.temperatureUnit.value == .system)
        #expect(manager.resolvedTemperatureUnit.value == .fahrenheit)

        manager.setTemperatureUnit(.celsius)
        // Derived properties recompute on the next main-actor turn.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(manager.resolvedTemperatureUnit.value == .celsius)
        #expect(manager.unitSettings.value.temperature == .celsius)
    }

    @Test func settingsPersistPerStore() {
        let store = InMemoryStorageEngine()
        makeManager(store: store).setWindSpeedUnit(.knots)

        #expect(makeManager(store: store).windSpeedUnit.value == .knots)
        #expect(makeManager(store: InMemoryStorageEngine()).windSpeedUnit.value == .milesPerHour)
    }

    @Test func restoreDefaultsResetsEverything() {
        let manager = makeManager(.metric)
        manager.setTemperatureUnit(.fahrenheit)
        manager.setPressureUnit(.inchesOfMercury)
        manager.setTimeFormat(.twelveHour)

        manager.restoreDefaults()

        #expect(manager.temperatureUnit.value == .system)
        #expect(manager.pressureUnit.value == .hectopascals)
        #expect(manager.timeFormat.value == .system)
    }
}

struct WeatherFormatterTests {
    private let enUS = Locale(identifier: "en_US")

    @Test func temperatures() {
        let celsius = WeatherFormatter(settings: .testSettings(temperature: .celsius), locale: enUS)
        let fahrenheit = WeatherFormatter(settings: .testSettings(temperature: .fahrenheit), locale: enUS)

        #expect(celsius.temperature(celsius: 21.6) == "22°")
        #expect(fahrenheit.temperature(celsius: 100) == "212°")
        #expect(fahrenheit.temperature(celsius: -40) == "-40°")
    }

    @Test func otherUnits() {
        let metric = WeatherFormatter(settings: .testSettings(), locale: enUS)
        let imperial = WeatherFormatter(
            settings: .testSettings(windSpeed: .milesPerHour, precipitation: .inches, pressure: .inchesOfMercury, distance: .miles),
            locale: enUS,
        )

        #expect(metric.windSpeed(kilometersPerHour: 16.09) == "16 km/h")
        #expect(imperial.windSpeed(kilometersPerHour: 16.09) == "10 mph")
        #expect(metric.precipitation(millimeters: 2.5) == "2.5 mm")
        #expect(imperial.precipitation(millimeters: 25.4) == "1 in")
        #expect(metric.pressure(hectopascals: 1013.25) == "1,013 hPa")
        #expect(imperial.pressure(hectopascals: 1013.25) == "29.92 inHg")
        #expect(imperial.distance(meters: 16093.4) == "10 mi")
    }

    @Test func timesUseThePlacesTimeZone() throws {
        let formatter = WeatherFormatter(settings: .testSettings(timeFormat: .twentyFourHour), locale: enUS)
        let date = try #require(ISO8601DateFormatter().date(from: "2026-11-11T20:30:00Z"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))

        #expect(formatter.time(date, in: newYork) == "15:30")
        #expect(formatter.hour(date, in: newYork) == "15")

        let twelveHour = WeatherFormatter(settings: .testSettings(timeFormat: .twelveHour), locale: enUS)
        #expect(twelveHour.time(date, in: newYork) == "3:30\u{202F}PM")
    }
}
