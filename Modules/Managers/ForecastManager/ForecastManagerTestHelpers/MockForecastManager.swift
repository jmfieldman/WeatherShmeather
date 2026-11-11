//
//  MockForecastManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import ForecastManager
import Foundation
import SwiftAsyncEx

@MainActor
public final class MockForecastManager: ForecastManager {
    public let mutableForecasts: MutableProperty<[String: Forecast]>
    public let mutableRefreshingPlaceIds = MutableProperty<Set<String>>([])
    public let mutableRefreshErrors = MutableProperty<[String: ForecastError]>([:])
    public private(set) var staleRefreshes: [String] = []
    public private(set) var refreshAllIfStaleCount = 0
    public private(set) var refreshAllCount = 0

    public private(set) lazy var forecasts: any PropertyProtocol<[String: Forecast]> = Property(mirroring: mutableForecasts)
    public private(set) lazy var refreshingPlaceIds: any PropertyProtocol<Set<String>> = Property(mirroring: mutableRefreshingPlaceIds)
    public private(set) lazy var refreshErrors: any PropertyProtocol<[String: ForecastError]> = Property(mirroring: mutableRefreshErrors)

    public init(forecasts: [String: Forecast] = [:]) {
        self.mutableForecasts = MutableProperty(forecasts)
    }

    public func refreshIfStale(placeId: String) {
        staleRefreshes.append(placeId)
    }

    public func refreshAllIfStale() {
        refreshAllIfStaleCount += 1
    }

    public func refreshAll() async {
        refreshAllCount += 1
    }
}

public extension Forecast {
    /// A simple forecast: `temperature` now, the given high and low today.
    static func testForecast(
        placeId: String,
        temperature: Double = 20,
        high: Double = 25,
        low: Double = 10,
        weatherCode: WeatherCode = .clear,
        fetchedAt: Date = Date(),
        timeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles")!,
    ) -> Forecast {
        let now = Date()
        return Forecast(
            placeId: placeId,
            fetchedAt: fetchedAt,
            latitude: 34,
            longitude: -118,
            timeZone: timeZone,
            current: CurrentConditions(
                time: now,
                temperature: temperature,
                apparentTemperature: temperature,
                humidity: 40,
                isDay: true,
                weatherCode: weatherCode,
                precipitation: 0,
                cloudCover: 0,
                pressure: 1013,
                windSpeed: 10,
                windDirection: 180,
                windGusts: 15,
            ),
            hourly: [],
            daily: [
                DailyForecast(
                    date: now,
                    weatherCode: weatherCode,
                    high: high,
                    low: low,
                    sunrise: nil,
                    sunset: nil,
                    uvIndexMax: 3,
                    precipitationSum: 0,
                    precipitationHours: 0,
                    precipitationProbabilityMax: 0,
                    windSpeedMax: 20,
                    windGustsMax: 30,
                    windDirectionDominant: 180,
                ),
            ],
            minutely: [],
            airQuality: nil,
        )
    }
}
