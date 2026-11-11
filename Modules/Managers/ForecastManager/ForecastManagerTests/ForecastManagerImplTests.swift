//
//  ForecastManagerImplTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import AppEnvironmentTestHelpers
import ForecastManager
@testable import ForecastManagerImpl
import Foundation
import Inject
import NetworkManager
import NetworkManagerTestHelpers
import PlacesManager
import PlacesManagerTestHelpers
import SlateManager
import SlateManagerTestHelpers
import Testing

/// A clock a test can move forward.
private final class TestClock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_794_432_600)
}

@MainActor
struct ForecastManagerImplTests {
    private let network = MockNetworkManager()
    private let places = MockPlacesManager(places: [.testPlace(id: "la", name: "Tarzana")])
    private let slate = MockSlateManager()
    private let clock = TestClock()

    private func forecastResponse() throws -> ForecastResponse {
        try JSONDecoder().decode(ForecastResponse.self, from: Data(ForecastFixtures.forecastJSON.utf8))
    }

    private func airQualityResponse() throws -> AirQualityResponse {
        try JSONDecoder().decode(AirQualityResponse.self, from: Data(ForecastFixtures.airQualityJSON.utf8))
    }

    private func stubNetwork(airQualityFails: Bool = false) throws {
        let forecast = try forecastResponse()
        let airQuality = try airQualityResponse()
        network.stub(GetForecastResource.self) { _, _ in forecast }
        network.stub(GetAirQualityResource.self) { _, _ throws(NetworkError) in
            if airQualityFails {
                throw .underlying(error: URLError(.badServerResponse))
            }
            return airQuality
        }
    }

    private func makeManager() -> ForecastManagerImpl {
        let environment = AppEnvironment.test()
        InjectionManager.register(AppEnvironment.self) { environment }
        InjectionManager.register(NetworkManager.self) { [network] in network }
        InjectionManager.register(SlateManager.self) { [slate] in slate }
        InjectionManager.register(PlacesManager.self) { [places] in places }
        InjectionManager.resetCurrentContainer()
        let clock = clock
        return ForecastManagerImpl(now: { clock.date })
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0 ..< 150 where !condition() {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func forecastRequests() -> Int {
        network.requestedPaths.filter { $0 == "/v1/forecast" }.count
    }

    // MARK: Parsing

    @Test func parsesTheRecordedResponse() throws {
        let forecast = try Forecast(
            placeId: "la",
            fetchedAt: Date(),
            latitude: 34,
            longitude: -118,
            response: forecastResponse(),
            airQuality: airQualityResponse(),
        )

        #expect(forecast.timeZone.identifier == "America/Los_Angeles")
        #expect(forecast.hourly.count == 48)
        #expect(forecast.daily.count == 16)
        #expect(forecast.minutely.count == 8)
        #expect(forecast.current.temperature == 30.0)
        #expect(forecast.current.weatherCode == .clear)
        #expect(forecast.airQuality?.usAqi == 62)
        // Air quality is merged into the matching hours.
        #expect(forecast.hourly.first?.usAqi == 62)

        // Daily dates are local midnight at the place.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = forecast.timeZone
        let components = try calendar.dateComponents([.hour, .minute], from: #require(forecast.today?.date))
        #expect(components.hour == 0 && components.minute == 0)
    }

    @Test func weatherCodesGroup() {
        #expect(WeatherCode(wmoCode: 61) == .rain)
        #expect(WeatherCode(wmoCode: 96) == .thunderstormWithHail)
        #expect(WeatherCode(wmoCode: 1234) == .unknown)
        #expect(WeatherCode.rain.isPrecipitation)
        #expect(!WeatherCode.overcast.isPrecipitation)
    }

    // MARK: Fetching and caching

    @Test func fetchesNewPlacesAndCachesThem() async throws {
        try stubNetwork()
        let manager = makeManager()

        await waitUntil { manager.forecasts.value["la"] != nil }
        #expect(manager.forecasts.value["la"]?.daily.count == 16)
        await waitUntil { manager.refreshingPlaceIds.value.isEmpty }

        // A new session reads the cache before any network call.
        network.stub(GetForecastResource.self) { _, _ throws(NetworkError) in
            throw .underlying(error: URLError(.notConnectedToInternet))
        }
        let next = makeManager()
        await waitUntil { next.forecasts.value["la"] != nil }
        #expect(next.forecasts.value["la"]?.hourly.count == 48)
        #expect(next.forecasts.value["la"]?.airQuality?.usAqi == 62)
    }

    @Test func freshForecastsAreNotRefetched() async throws {
        try stubNetwork()
        let manager = makeManager()
        await waitUntil { manager.forecasts.value["la"] != nil && manager.refreshingPlaceIds.value.isEmpty }
        #expect(forecastRequests() == 1)

        clock.date.addTimeInterval(10 * 60)
        manager.refreshIfStale(placeId: "la")
        await waitUntil { manager.refreshingPlaceIds.value.isEmpty }
        #expect(forecastRequests() == 1)

        clock.date.addTimeInterval(10 * 60)
        manager.refreshIfStale(placeId: "la")
        await waitUntil { forecastRequests() == 2 }
        #expect(forecastRequests() == 2)
    }

    @Test func refreshAllIgnoresAge() async throws {
        try stubNetwork()
        let manager = makeManager()
        await waitUntil { manager.forecasts.value["la"] != nil && manager.refreshingPlaceIds.value.isEmpty }

        await manager.refreshAll()

        #expect(forecastRequests() == 2)
    }

    @Test func missingAirQualityStillSavesTheForecast() async throws {
        try stubNetwork(airQualityFails: true)
        let manager = makeManager()

        await waitUntil { manager.forecasts.value["la"] != nil }

        #expect(manager.forecasts.value["la"]?.airQuality == nil)
        #expect(manager.forecasts.value["la"]?.hourly.first?.usAqi == nil)
    }

    @Test func offlineIsReportedPerPlace() async {
        network.stub(GetForecastResource.self) { _, _ throws(NetworkError) in
            throw .underlying(error: URLError(.notConnectedToInternet))
        }
        network.stub(GetAirQualityResource.self) { _, _ throws(NetworkError) in
            throw .underlying(error: URLError(.notConnectedToInternet))
        }
        let manager = makeManager()

        await waitUntil { manager.refreshErrors.value["la"] != nil }

        #expect(manager.refreshErrors.value["la"] == .offline)
        #expect(manager.forecasts.value["la"] == nil)
    }

    @Test func removingAPlaceDeletesItsForecast() async throws {
        try stubNetwork()
        let manager = makeManager()
        await waitUntil { manager.forecasts.value["la"] != nil }

        places.mutablePlaces.value = []
        await waitUntil { manager.forecasts.value["la"] == nil }

        #expect(manager.forecasts.value.isEmpty)
    }
}
