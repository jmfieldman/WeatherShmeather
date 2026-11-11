//
//  GetForecastResource.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import NetworkModels

/// `GET /v1/forecast` on Open-Meteo's forecast API.
struct GetForecastResource: NetworkRestResource {
    typealias Request = ForecastRequest
    typealias Response = ForecastResponse
    let service: NetworkService = .forecast
    let path = "/v1/forecast"
}

/// Always metric (Open-Meteo's default units), always unix times, and always
/// the place's own time zone, so daily values line up with its days.
struct ForecastRequest: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
    let current = [
        "temperature_2m", "apparent_temperature", "relative_humidity_2m", "is_day", "weather_code",
        "precipitation", "cloud_cover", "pressure_msl", "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m",
    ]
    let minutely15 = ["precipitation"]
    let forecastMinutely15 = 8
    let hourly = [
        "temperature_2m", "apparent_temperature", "precipitation_probability", "precipitation", "weather_code",
        "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m", "uv_index", "visibility", "relative_humidity_2m", "is_day",
    ]
    let forecastHours = 48
    let daily = [
        "weather_code", "temperature_2m_max", "temperature_2m_min", "sunrise", "sunset", "uv_index_max",
        "precipitation_sum", "precipitation_hours", "precipitation_probability_max", "wind_speed_10m_max",
        "wind_gusts_10m_max", "wind_direction_10m_dominant",
    ]
    let forecastDays = 16
    let timezone = "auto"
    let timeformat = "unixtime"

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case current
        case minutely15 = "minutely_15"
        case forecastMinutely15 = "forecast_minutely_15"
        case hourly
        case forecastHours = "forecast_hours"
        case daily
        case forecastDays = "forecast_days"
        case timezone
        case timeformat
    }
}

/// Mirrors Open-Meteo's response. Series are columnar arrays, one per
/// variable, aligned with `time`; any value may be `null`.
struct ForecastResponse: Decodable, Sendable {
    let timezone: String
    let current: Current
    let minutely15: Minutely?
    let hourly: Hourly
    let daily: Daily

    enum CodingKeys: String, CodingKey {
        case timezone
        case current
        case minutely15 = "minutely_15"
        case hourly
        case daily
    }

    struct Current: Decodable, Sendable {
        let time: TimeInterval
        let temperature2m: Double?
        let apparentTemperature: Double?
        let relativeHumidity2m: Double?
        let isDay: Int?
        let weatherCode: Int?
        let precipitation: Double?
        let cloudCover: Double?
        let pressureMsl: Double?
        let windSpeed10m: Double?
        let windDirection10m: Double?
        let windGusts10m: Double?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case relativeHumidity2m = "relative_humidity_2m"
            case isDay = "is_day"
            case weatherCode = "weather_code"
            case precipitation
            case cloudCover = "cloud_cover"
            case pressureMsl = "pressure_msl"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
            case windGusts10m = "wind_gusts_10m"
        }
    }

    struct Minutely: Decodable, Sendable {
        let time: [TimeInterval]
        let precipitation: [Double?]
    }

    struct Hourly: Decodable, Sendable {
        let time: [TimeInterval]
        let temperature2m: [Double?]
        let apparentTemperature: [Double?]
        let precipitationProbability: [Int?]
        let precipitation: [Double?]
        let weatherCode: [Int?]
        let windSpeed10m: [Double?]
        let windDirection10m: [Double?]
        let windGusts10m: [Double?]
        let uvIndex: [Double?]
        let visibility: [Double?]
        let relativeHumidity2m: [Double?]
        let isDay: [Int?]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitationProbability = "precipitation_probability"
            case precipitation
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
            case windGusts10m = "wind_gusts_10m"
            case uvIndex = "uv_index"
            case visibility
            case relativeHumidity2m = "relative_humidity_2m"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable, Sendable {
        let time: [TimeInterval]
        let weatherCode: [Int?]
        let temperature2mMax: [Double?]
        let temperature2mMin: [Double?]
        let sunrise: [TimeInterval?]
        let sunset: [TimeInterval?]
        let uvIndexMax: [Double?]
        let precipitationSum: [Double?]
        let precipitationHours: [Double?]
        let precipitationProbabilityMax: [Int?]
        let windSpeed10mMax: [Double?]
        let windGusts10mMax: [Double?]
        let windDirection10mDominant: [Double?]

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case sunrise
            case sunset
            case uvIndexMax = "uv_index_max"
            case precipitationSum = "precipitation_sum"
            case precipitationHours = "precipitation_hours"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case windSpeed10mMax = "wind_speed_10m_max"
            case windGusts10mMax = "wind_gusts_10m_max"
            case windDirection10mDominant = "wind_direction_10m_dominant"
        }
    }
}
