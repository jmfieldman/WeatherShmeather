//
//  StoredHourlyForecast.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SlateSchema

/// One hour of one place's forecast, with that hour's air quality merged in.
@SlateEntity
public struct StoredHourlyForecast {
    #Index<StoredHourlyForecast>([\.placeId, \.time])

    public let placeId: String
    public let time: Date
    public let temperature: Double
    public let apparentTemperature: Double
    public let precipitationProbability: Int64?
    public let precipitation: Double
    public let weatherCode: Int64
    public let windSpeed: Double
    public let windDirection: Double
    public let windGusts: Double
    public let uvIndex: Double
    public let visibility: Double
    public let humidity: Double
    public let isDay: Bool
    public let usAqi: Int64?
    public let europeanAqi: Int64?
}
