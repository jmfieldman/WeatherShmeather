//
//  Forecast.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// Everything known about one place's weather, in metric units: °C, km/h,
/// mm, hPa, meters, and percent.
public struct Forecast: Hashable, Sendable {
    public let placeId: String
    public let fetchedAt: Date
    public let latitude: Double
    public let longitude: Double
    public let timeZone: TimeZone
    public let current: CurrentConditions
    /// The next 48 hours, starting with the current hour.
    public let hourly: [HourlyForecast]
    /// The next 16 days, starting today.
    public let daily: [DailyForecast]
    /// The next two hours in 15-minute steps.
    public let minutely: [MinutelyPrecipitation]
    /// `nil` where Open-Meteo has no air-quality coverage.
    public let airQuality: AirQuality?

    public init(
        placeId: String,
        fetchedAt: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        current: CurrentConditions,
        hourly: [HourlyForecast],
        daily: [DailyForecast],
        minutely: [MinutelyPrecipitation],
        airQuality: AirQuality?,
    ) {
        self.placeId = placeId
        self.fetchedAt = fetchedAt
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
        self.current = current
        self.hourly = hourly
        self.daily = daily
        self.minutely = minutely
        self.airQuality = airQuality
    }

    /// Today's entry, the first in `daily`.
    public var today: DailyForecast? {
        daily.first
    }
}

public struct CurrentConditions: Hashable, Sendable {
    public let time: Date
    public let temperature: Double
    public let apparentTemperature: Double
    public let humidity: Double
    public let isDay: Bool
    public let weatherCode: WeatherCode
    public let precipitation: Double
    public let cloudCover: Double
    public let pressure: Double
    public let windSpeed: Double
    public let windDirection: Double
    public let windGusts: Double

    public init(
        time: Date,
        temperature: Double,
        apparentTemperature: Double,
        humidity: Double,
        isDay: Bool,
        weatherCode: WeatherCode,
        precipitation: Double,
        cloudCover: Double,
        pressure: Double,
        windSpeed: Double,
        windDirection: Double,
        windGusts: Double,
    ) {
        self.time = time
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.humidity = humidity
        self.isDay = isDay
        self.weatherCode = weatherCode
        self.precipitation = precipitation
        self.cloudCover = cloudCover
        self.pressure = pressure
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.windGusts = windGusts
    }
}

public struct HourlyForecast: Hashable, Sendable {
    public let time: Date
    public let temperature: Double
    public let apparentTemperature: Double
    public let precipitationProbability: Int?
    public let precipitation: Double
    public let weatherCode: WeatherCode
    public let windSpeed: Double
    public let windDirection: Double
    public let windGusts: Double
    public let uvIndex: Double
    public let visibility: Double
    public let humidity: Double
    public let isDay: Bool
    public let usAqi: Int?
    public let europeanAqi: Int?

    public init(
        time: Date,
        temperature: Double,
        apparentTemperature: Double,
        precipitationProbability: Int?,
        precipitation: Double,
        weatherCode: WeatherCode,
        windSpeed: Double,
        windDirection: Double,
        windGusts: Double,
        uvIndex: Double,
        visibility: Double,
        humidity: Double,
        isDay: Bool,
        usAqi: Int?,
        europeanAqi: Int?,
    ) {
        self.time = time
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.precipitationProbability = precipitationProbability
        self.precipitation = precipitation
        self.weatherCode = weatherCode
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.windGusts = windGusts
        self.uvIndex = uvIndex
        self.visibility = visibility
        self.humidity = humidity
        self.isDay = isDay
        self.usAqi = usAqi
        self.europeanAqi = europeanAqi
    }
}

public struct DailyForecast: Hashable, Sendable {
    /// Local midnight at the place.
    public let date: Date
    public let weatherCode: WeatherCode
    public let high: Double
    public let low: Double
    public let sunrise: Date?
    public let sunset: Date?
    public let uvIndexMax: Double
    public let precipitationSum: Double
    public let precipitationHours: Double
    public let precipitationProbabilityMax: Int?
    public let windSpeedMax: Double
    public let windGustsMax: Double
    public let windDirectionDominant: Double

    public init(
        date: Date,
        weatherCode: WeatherCode,
        high: Double,
        low: Double,
        sunrise: Date?,
        sunset: Date?,
        uvIndexMax: Double,
        precipitationSum: Double,
        precipitationHours: Double,
        precipitationProbabilityMax: Int?,
        windSpeedMax: Double,
        windGustsMax: Double,
        windDirectionDominant: Double,
    ) {
        self.date = date
        self.weatherCode = weatherCode
        self.high = high
        self.low = low
        self.sunrise = sunrise
        self.sunset = sunset
        self.uvIndexMax = uvIndexMax
        self.precipitationSum = precipitationSum
        self.precipitationHours = precipitationHours
        self.precipitationProbabilityMax = precipitationProbabilityMax
        self.windSpeedMax = windSpeedMax
        self.windGustsMax = windGustsMax
        self.windDirectionDominant = windDirectionDominant
    }
}

public struct MinutelyPrecipitation: Hashable, Sendable {
    public let time: Date
    public let precipitation: Double

    public init(time: Date, precipitation: Double) {
        self.time = time
        self.precipitation = precipitation
    }
}

public struct AirQuality: Hashable, Sendable {
    public let usAqi: Int?
    public let europeanAqi: Int?
    /// µg/m³.
    public let pm25: Double?
    public let pm10: Double?
    public let ozone: Double?

    public init(usAqi: Int?, europeanAqi: Int?, pm25: Double?, pm10: Double?, ozone: Double?) {
        self.usAqi = usAqi
        self.europeanAqi = europeanAqi
        self.pm25 = pm25
        self.pm10 = pm10
        self.ozone = ozone
    }
}
