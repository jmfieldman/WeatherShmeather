//
//  StoredForecastSummary.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SlateSchema

/// One row per place: when its weather was fetched, where for, and the
/// single-value parts of the answer (current conditions and current air
/// quality). The time series live in their own tables, keyed by `placeId`.
@SlateEntity
public struct StoredForecastSummary {
    #Unique<StoredForecastSummary>([\.placeId])

    public let placeId: String
    public let fetchedAt: Date
    /// The coordinate the forecast is for. The current location's row moves,
    /// and a forecast for the old spot is refetched.
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String

    public let currentTime: Date
    public let temperature: Double
    public let apparentTemperature: Double
    public let humidity: Double
    public let isDay: Bool
    public let weatherCode: Int64
    public let precipitation: Double
    public let cloudCover: Double
    public let pressure: Double
    public let windSpeed: Double
    public let windDirection: Double
    public let windGusts: Double

    public let usAqi: Int64?
    public let europeanAqi: Int64?
    public let pm25: Double?
    public let pm10: Double?
    public let ozone: Double?
}
