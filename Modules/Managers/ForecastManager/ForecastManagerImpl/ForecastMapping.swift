//
//  ForecastMapping.swift
//  Copyright © 2026 WeatherShmeather.
//

import ForecastManager
import ForecastModels
import Foundation

// MARK: - Wire to domain

extension Forecast {
    /// Zips Open-Meteo's columnar series into rows. A row missing the values
    /// it can't be shown without, such as an hour with no temperature, is
    /// dropped; any other missing value falls back to zero or `nil`.
    init(
        placeId: String,
        fetchedAt: Date,
        latitude: Double,
        longitude: Double,
        response: ForecastResponse,
        airQuality: AirQualityResponse?,
    ) {
        let hourlyAqi = Self.hourlyAqi(from: airQuality)

        let hourly = response.hourly
        let hours: [HourlyForecast] = hourly.time.indices.compactMap { index in
            guard let temperature = hourly.temperature2m[safe: index] ?? nil else {
                return nil
            }

            let time = hourly.time[index]
            return HourlyForecast(
                time: Date(timeIntervalSince1970: time),
                temperature: temperature,
                apparentTemperature: hourly.apparentTemperature[safe: index].flatMap(\.self) ?? temperature,
                precipitationProbability: hourly.precipitationProbability[safe: index] ?? nil,
                precipitation: hourly.precipitation[safe: index].flatMap(\.self) ?? 0,
                weatherCode: WeatherCode(wmoCode: hourly.weatherCode[safe: index].flatMap(\.self) ?? -1),
                windSpeed: hourly.windSpeed10m[safe: index].flatMap(\.self) ?? 0,
                windDirection: hourly.windDirection10m[safe: index].flatMap(\.self) ?? 0,
                windGusts: hourly.windGusts10m[safe: index].flatMap(\.self) ?? 0,
                uvIndex: hourly.uvIndex[safe: index].flatMap(\.self) ?? 0,
                visibility: hourly.visibility[safe: index].flatMap(\.self) ?? 0,
                humidity: hourly.relativeHumidity2m[safe: index].flatMap(\.self) ?? 0,
                isDay: (hourly.isDay[safe: index].flatMap(\.self) ?? 1) == 1,
                usAqi: hourlyAqi[time]?.us,
                europeanAqi: hourlyAqi[time]?.european,
            )
        }

        let daily = response.daily
        let days: [DailyForecast] = daily.time.indices.compactMap { index in
            guard
                let high = daily.temperature2mMax[safe: index] ?? nil,
                let low = daily.temperature2mMin[safe: index] ?? nil
            else {
                return nil
            }

            return DailyForecast(
                date: Date(timeIntervalSince1970: daily.time[index]),
                weatherCode: WeatherCode(wmoCode: daily.weatherCode[safe: index].flatMap(\.self) ?? -1),
                high: high,
                low: low,
                sunrise: daily.sunrise[safe: index].flatMap(\.self).map(Date.init(timeIntervalSince1970:)),
                sunset: daily.sunset[safe: index].flatMap(\.self).map(Date.init(timeIntervalSince1970:)),
                uvIndexMax: daily.uvIndexMax[safe: index].flatMap(\.self) ?? 0,
                precipitationSum: daily.precipitationSum[safe: index].flatMap(\.self) ?? 0,
                precipitationHours: daily.precipitationHours[safe: index].flatMap(\.self) ?? 0,
                precipitationProbabilityMax: daily.precipitationProbabilityMax[safe: index] ?? nil,
                windSpeedMax: daily.windSpeed10mMax[safe: index].flatMap(\.self) ?? 0,
                windGustsMax: daily.windGusts10mMax[safe: index].flatMap(\.self) ?? 0,
                windDirectionDominant: daily.windDirection10mDominant[safe: index].flatMap(\.self) ?? 0,
            )
        }

        let minutely: [MinutelyPrecipitation] = response.minutely15.map { series in
            series.time.indices.map { index in
                MinutelyPrecipitation(
                    time: Date(timeIntervalSince1970: series.time[index]),
                    precipitation: series.precipitation[safe: index].flatMap(\.self) ?? 0,
                )
            }
        } ?? []

        let current = response.current
        let currentTemperature = current.temperature2m ?? hours.first?.temperature ?? 0
        self.init(
            placeId: placeId,
            fetchedAt: fetchedAt,
            latitude: latitude,
            longitude: longitude,
            timeZone: TimeZone(identifier: response.timezone) ?? .current,
            current: CurrentConditions(
                time: Date(timeIntervalSince1970: current.time),
                temperature: currentTemperature,
                apparentTemperature: current.apparentTemperature ?? currentTemperature,
                humidity: current.relativeHumidity2m ?? 0,
                isDay: (current.isDay ?? 1) == 1,
                weatherCode: WeatherCode(wmoCode: current.weatherCode ?? -1),
                precipitation: current.precipitation ?? 0,
                cloudCover: current.cloudCover ?? 0,
                pressure: current.pressureMsl ?? 0,
                windSpeed: current.windSpeed10m ?? 0,
                windDirection: current.windDirection10m ?? 0,
                windGusts: current.windGusts10m ?? 0,
            ),
            hourly: hours,
            daily: days,
            minutely: minutely,
            airQuality: Self.currentAirQuality(from: airQuality),
        )
    }

    private static func hourlyAqi(from response: AirQualityResponse?) -> [TimeInterval: (us: Int?, european: Int?)] {
        guard let hourly = response?.hourly else {
            return [:]
        }

        var result: [TimeInterval: (us: Int?, european: Int?)] = [:]
        for (index, time) in hourly.time.enumerated() {
            result[time] = (hourly.usAqi[safe: index] ?? nil, hourly.europeanAqi[safe: index] ?? nil)
        }
        return result
    }

    /// `nil` unless at least one value came back: coverage is regional.
    private static func currentAirQuality(from response: AirQualityResponse?) -> AirQuality? {
        guard let current = response?.current else {
            return nil
        }

        let airQuality = AirQuality(
            usAqi: current.usAqi,
            europeanAqi: current.europeanAqi,
            pm25: current.pm25,
            pm10: current.pm10,
            ozone: current.ozone,
        )
        let hasAnyValue = airQuality.usAqi != nil || airQuality.europeanAqi != nil || airQuality.pm25 != nil
            || airQuality.pm10 != nil || airQuality.ozone != nil
        return hasAnyValue ? airQuality : nil
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Stored rows to domain

extension Forecast {
    init(
        summary: StoredForecastSummary,
        hourly: [StoredHourlyForecast],
        daily: [StoredDailyForecast],
        minutely: [StoredMinutelyPrecipitation],
    ) {
        let airQuality: AirQuality? =
            if summary.usAqi != nil || summary.europeanAqi != nil || summary.pm25 != nil
                || summary.pm10 != nil || summary.ozone != nil
            {
                AirQuality(
                    usAqi: summary.usAqi.map(Int.init),
                    europeanAqi: summary.europeanAqi.map(Int.init),
                    pm25: summary.pm25,
                    pm10: summary.pm10,
                    ozone: summary.ozone,
                )
            } else {
                nil
            }

        self.init(
            placeId: summary.placeId,
            fetchedAt: summary.fetchedAt,
            latitude: summary.latitude,
            longitude: summary.longitude,
            timeZone: TimeZone(identifier: summary.timeZoneIdentifier) ?? .current,
            current: CurrentConditions(
                time: summary.currentTime,
                temperature: summary.temperature,
                apparentTemperature: summary.apparentTemperature,
                humidity: summary.humidity,
                isDay: summary.isDay,
                weatherCode: WeatherCode(wmoCode: Int(summary.weatherCode)),
                precipitation: summary.precipitation,
                cloudCover: summary.cloudCover,
                pressure: summary.pressure,
                windSpeed: summary.windSpeed,
                windDirection: summary.windDirection,
                windGusts: summary.windGusts,
            ),
            hourly: hourly.map { row in
                HourlyForecast(
                    time: row.time,
                    temperature: row.temperature,
                    apparentTemperature: row.apparentTemperature,
                    precipitationProbability: row.precipitationProbability.map(Int.init),
                    precipitation: row.precipitation,
                    weatherCode: WeatherCode(wmoCode: Int(row.weatherCode)),
                    windSpeed: row.windSpeed,
                    windDirection: row.windDirection,
                    windGusts: row.windGusts,
                    uvIndex: row.uvIndex,
                    visibility: row.visibility,
                    humidity: row.humidity,
                    isDay: row.isDay,
                    usAqi: row.usAqi.map(Int.init),
                    europeanAqi: row.europeanAqi.map(Int.init),
                )
            },
            daily: daily.map { row in
                DailyForecast(
                    date: row.date,
                    weatherCode: WeatherCode(wmoCode: Int(row.weatherCode)),
                    high: row.high,
                    low: row.low,
                    sunrise: row.sunrise,
                    sunset: row.sunset,
                    uvIndexMax: row.uvIndexMax,
                    precipitationSum: row.precipitationSum,
                    precipitationHours: row.precipitationHours,
                    precipitationProbabilityMax: row.precipitationProbabilityMax.map(Int.init),
                    windSpeedMax: row.windSpeedMax,
                    windGustsMax: row.windGustsMax,
                    windDirectionDominant: row.windDirectionDominant,
                )
            },
            minutely: minutely.map { MinutelyPrecipitation(time: $0.time, precipitation: $0.precipitation) },
            airQuality: airQuality,
        )
    }
}

// MARK: - Domain to stored rows

extension WeatherCode {
    /// A representative WMO code for storage. Grouping is lossy, so a
    /// stored code maps back to the same group, not the same original code.
    var wmoCode: Int64 {
        switch self {
        case .clear: 0
        case .mainlyClear: 1
        case .partlyCloudy: 2
        case .overcast: 3
        case .fog: 45
        case .drizzle: 53
        case .freezingDrizzle: 56
        case .rain: 63
        case .heavyRain: 65
        case .freezingRain: 66
        case .snow: 73
        case .heavySnow: 75
        case .rainShowers: 81
        case .snowShowers: 85
        case .thunderstorm: 95
        case .thunderstormWithHail: 96
        case .unknown: -1
        }
    }
}
