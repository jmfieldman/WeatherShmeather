//
//  GetAirQualityResource.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import NetworkModels

/// `GET /v1/air-quality` on Open-Meteo's air-quality API.
struct GetAirQualityResource: NetworkRestResource {
    typealias Request = AirQualityRequest
    typealias Response = AirQualityResponse
    let service: NetworkService = .airQuality
    let path = "/v1/air-quality"
}

struct AirQualityRequest: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
    let current = ["us_aqi", "european_aqi", "pm2_5", "pm10", "ozone"]
    let hourly = ["us_aqi", "european_aqi"]
    let forecastHours = 24
    let timezone = "auto"
    let timeformat = "unixtime"

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case current
        case hourly
        case forecastHours = "forecast_hours"
        case timezone
        case timeformat
    }
}

struct AirQualityResponse: Decodable, Sendable {
    let current: Current?
    let hourly: Hourly?

    struct Current: Decodable, Sendable {
        let usAqi: Int?
        let europeanAqi: Int?
        let pm25: Double?
        let pm10: Double?
        let ozone: Double?

        enum CodingKeys: String, CodingKey {
            case usAqi = "us_aqi"
            case europeanAqi = "european_aqi"
            case pm25 = "pm2_5"
            case pm10
            case ozone
        }
    }

    struct Hourly: Decodable, Sendable {
        let time: [TimeInterval]
        let usAqi: [Int?]
        let europeanAqi: [Int?]

        enum CodingKeys: String, CodingKey {
            case time
            case usAqi = "us_aqi"
            case europeanAqi = "european_aqi"
        }
    }
}
