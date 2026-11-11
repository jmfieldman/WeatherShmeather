//
//  StoredDailyForecast.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SlateSchema

/// One day of one place's forecast. `date` is local midnight at the place.
@SlateEntity
public struct StoredDailyForecast {
    #Index<StoredDailyForecast>([\.placeId, \.date])

    public let placeId: String
    public let date: Date
    public let weatherCode: Int64
    public let high: Double
    public let low: Double
    public let sunrise: Date?
    public let sunset: Date?
    public let uvIndexMax: Double
    public let precipitationSum: Double
    public let precipitationHours: Double
    public let precipitationProbabilityMax: Int64?
    public let windSpeedMax: Double
    public let windGustsMax: Double
    public let windDirectionDominant: Double
}
