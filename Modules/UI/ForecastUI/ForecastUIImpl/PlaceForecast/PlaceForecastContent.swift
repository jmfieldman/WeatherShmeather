//
//  PlaceForecastContent.swift
//  Copyright © 2026 WeatherShmeather.
//

import ForecastManager
import ForecastUIResources
import Foundation
import PlacesManager
import PreferencesManager
import WeatherDisplay

/// Everything the forecast page shows, as display-ready values.
///
/// Built by one pure function from a place, its forecast, the user's units,
/// and the time. All of the page's display rules live in `make`, which is
/// what the tests cover; the view only lays these values out.
public struct PlaceForecastContent: Equatable, Sendable {
    public struct Header: Equatable, Sendable {
        public let isCurrentLocation: Bool
        public let name: String
        public let temperature: String
        public let condition: String
        public let highLow: String
    }

    /// One column of the Conditions strip.
    public struct HourColumn: Equatable, Sendable, Identifiable {
        public let id: Date
        public let label: String
        public let weatherCode: WeatherCode
        public let isDay: Bool
        public let temperature: String
        /// "40%" when there's a meaningful chance, otherwise `nil`.
        public let precipitationChance: String?
        public let precipitationAmount: String
        public let windSpeed: String
        public let windDirectionDegrees: Double
    }

    /// One 15-minute bar of the next-two-hours chart.
    public struct PrecipitationBar: Equatable, Sendable, Identifiable {
        public let id: Date
        /// 0 to 1, relative to the wettest step.
        public let fraction: Double
        public let label: String
    }

    public struct DayRow: Equatable, Sendable, Identifiable {
        public let id: Date
        public let weekday: String
        public let weatherCode: WeatherCode
        public let precipitationChance: String?
        public let low: String
        public let high: String
        /// The day's range within the range of every day shown, 0 to 1.
        public let rangeStart: Double
        public let rangeEnd: Double
        /// Today's current temperature on the same scale, for today's row.
        public let currentMarker: Double?
    }

    public struct AirQualityContent: Equatable, Sendable {
        public struct Reading: Equatable, Sendable, Identifiable {
            public let id: String
            public let name: String
            public let value: String
        }

        public let value: String
        public let category: String
        public let scaleName: String
        /// Where the value sits on the scale, 0 to 1.
        public let fraction: Double
        public let pollutants: [Reading]
        /// The next 24 hours, every third hour.
        public let upcoming: [Reading]
    }

    public struct WindContent: Equatable, Sendable {
        public let speed: String
        public let gusts: String
        public let direction: String
        public let directionDegrees: Double
        public let todayMax: String
    }

    public struct PrecipitationContent: Equatable, Sendable {
        public let today: String
        public let outlook: String
    }

    public struct Detail: Equatable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let value: String
    }

    public let header: Header
    public let weatherCode: WeatherCode
    public let isDay: Bool
    public let hours: [HourColumn]
    /// `nil` unless any precipitation is expected in the next two hours.
    public let nextTwoHours: [PrecipitationBar]?
    public let days: [DayRow]
    public let airQuality: AirQualityContent?
    public let wind: WindContent
    public let precipitation: PrecipitationContent
    public let details: [Detail]
}

// MARK: - Building

public extension PlaceForecastContent {
    /// The minimum chance worth showing beside an hour or a day.
    static let precipitationChanceThreshold = 20
    /// The most precipitation a 15-minute step can have and still count as dry, in mm.
    static let dryStepThreshold = 0.05
    /// A day counts as wet for the outlook above this total, in mm.
    static let wetDayThreshold = 1.0

    static func make(place: Place, forecast: Forecast, settings: UnitSettings, now: Date) -> PlaceForecastContent {
        let formatter = WeatherFormatter(settings: settings)
        let timeZone = forecast.timeZone
        let current = forecast.current
        let today = forecast.today

        let header = Header(
            isCurrentLocation: place.isCurrentLocation,
            name: place.name,
            temperature: formatter.temperature(celsius: current.temperature),
            condition: current.weatherCode.name(isDay: current.isDay),
            highLow: today.map {
                .highLow(high: formatter.temperature(celsius: $0.high), low: formatter.temperature(celsius: $0.low))
            } ?? "",
        )

        return PlaceForecastContent(
            header: header,
            weatherCode: current.weatherCode,
            isDay: current.isDay,
            hours: hourColumns(forecast, formatter: formatter, now: now),
            nextTwoHours: precipitationBars(forecast, formatter: formatter),
            days: dayRows(forecast, formatter: formatter),
            airQuality: airQuality(forecast, settings: settings, formatter: formatter),
            wind: WindContent(
                speed: formatter.windSpeed(kilometersPerHour: current.windSpeed),
                gusts: formatter.windSpeed(kilometersPerHour: current.windGusts),
                direction: compassPoint(degrees: current.windDirection),
                directionDegrees: current.windDirection,
                todayMax: today.map { formatter.windSpeed(kilometersPerHour: $0.windSpeedMax) } ?? "—",
            ),
            precipitation: precipitation(forecast, formatter: formatter),
            details: details(forecast, formatter: formatter, timeZone: timeZone),
        )
    }

    private static func hourColumns(_ forecast: Forecast, formatter: WeatherFormatter, now: Date) -> [HourColumn] {
        // The first column is the hour that contains `now`.
        let upcoming = forecast.hourly.filter { $0.time.addingTimeInterval(3600) > now }.prefix(24)
        return upcoming.enumerated().map { index, hour in
            HourColumn(
                id: hour.time,
                label: index == 0 ? .ForecastUI.forecastNow : formatter.hour(hour.time, in: forecast.timeZone),
                weatherCode: hour.weatherCode,
                isDay: hour.isDay,
                temperature: formatter.temperature(celsius: hour.temperature),
                precipitationChance: hour.precipitationProbability.flatMap { $0 >= precipitationChanceThreshold ? "\($0)%" : nil },
                precipitationAmount: formatter.precipitation(millimeters: hour.precipitation),
                windSpeed: formatter.windSpeed(kilometersPerHour: hour.windSpeed),
                windDirectionDegrees: hour.windDirection,
            )
        }
    }

    private static func precipitationBars(_ forecast: Forecast, formatter: WeatherFormatter) -> [PrecipitationBar]? {
        let steps = forecast.minutely
        guard let wettest = steps.map(\.precipitation).max(), wettest > dryStepThreshold else {
            return nil
        }

        return steps.map { step in
            PrecipitationBar(
                id: step.time,
                fraction: step.precipitation / wettest,
                label: formatter.time(step.time, in: forecast.timeZone),
            )
        }
    }

    private static func dayRows(_ forecast: Forecast, formatter: WeatherFormatter) -> [DayRow] {
        let days = forecast.daily
        guard let minimum = days.map(\.low).min(), let maximum = days.map(\.high).max() else {
            return []
        }

        let span = max(maximum - minimum, 1)
        let position = { (celsius: Double) in min(max((celsius - minimum) / span, 0), 1) }

        return days.enumerated().map { index, day in
            DayRow(
                id: day.date,
                weekday: index == 0
                    ? .ForecastUI.forecastToday
                    : day.date.formatted(Date.FormatStyle(timeZone: forecast.timeZone).weekday(.abbreviated)),
                weatherCode: day.weatherCode,
                precipitationChance: day.precipitationProbabilityMax.flatMap {
                    $0 >= precipitationChanceThreshold ? "\($0)%" : nil
                },
                low: formatter.temperature(celsius: day.low),
                high: formatter.temperature(celsius: day.high),
                rangeStart: position(day.low),
                rangeEnd: position(day.high),
                currentMarker: index == 0 ? position(forecast.current.temperature) : nil,
            )
        }
    }

    private static func airQuality(
        _ forecast: Forecast,
        settings: UnitSettings,
        formatter: WeatherFormatter,
    ) -> AirQualityContent? {
        guard let airQuality = forecast.airQuality else {
            return nil
        }

        let isUS = settings.airQualityScale == .unitedStates
        guard let value = isUS ? airQuality.usAqi : airQuality.europeanAqi else {
            return nil
        }

        let micrograms = { (value: Double?) -> String in
            value.map { String.ForecastUI.forecastMicrograms($0.formatted(.number.precision(.fractionLength(0 ... 1)))) } ?? "—"
        }
        let upcoming = forecast.hourly.prefix(24).enumerated().compactMap { index, hour -> AirQualityContent.Reading? in
            guard index.isMultiple(of: 3), let hourValue = isUS ? hour.usAqi : hour.europeanAqi else {
                return nil
            }

            return AirQualityContent.Reading(
                id: "\(hour.time.timeIntervalSince1970)",
                name: index == 0 ? .ForecastUI.forecastNow : formatter.hour(hour.time, in: forecast.timeZone),
                value: "\(hourValue)",
            )
        }

        return AirQualityContent(
            value: "\(value)",
            category: isUS ? usCategory(value) : europeanCategory(value),
            scaleName: isUS ? .ForecastUI.aqiScaleUs : .ForecastUI.aqiScaleEu,
            fraction: min(Double(value) / (isUS ? 300 : 100), 1),
            pollutants: [
                .init(id: "pm25", name: .ForecastUI.forecastPm25, value: micrograms(airQuality.pm25)),
                .init(id: "pm10", name: .ForecastUI.forecastPm10, value: micrograms(airQuality.pm10)),
                .init(id: "ozone", name: .ForecastUI.forecastOzone, value: micrograms(airQuality.ozone)),
            ],
            upcoming: upcoming,
        )
    }

    /// The US EPA's AQI categories.
    static func usCategory(_ value: Int) -> String {
        switch value {
        case ..<51: .ForecastUI.aqiUsGood
        case ..<101: .ForecastUI.aqiUsModerate
        case ..<151: .ForecastUI.aqiUsSensitive
        case ..<201: .ForecastUI.aqiUsUnhealthy
        case ..<301: .ForecastUI.aqiUsVeryUnhealthy
        default: .ForecastUI.aqiUsHazardous
        }
    }

    /// The European Environment Agency's AQI categories.
    static func europeanCategory(_ value: Int) -> String {
        switch value {
        case ..<20: .ForecastUI.aqiEuGood
        case ..<40: .ForecastUI.aqiEuFair
        case ..<60: .ForecastUI.aqiEuModerate
        case ..<80: .ForecastUI.aqiEuPoor
        case ..<100: .ForecastUI.aqiEuVeryPoor
        default: .ForecastUI.aqiEuExtremelyPoor
        }
    }

    /// "SW" for 225°: the nearest of eight compass points the wind comes from.
    static func compassPoint(degrees: Double) -> String {
        let points: [String] = [
            .ForecastUI.compassNorth, .ForecastUI.compassNortheast, .ForecastUI.compassEast, .ForecastUI.compassSoutheast,
            .ForecastUI.compassSouth, .ForecastUI.compassSouthwest, .ForecastUI.compassWest, .ForecastUI.compassNorthwest,
        ]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return points[Int((normalized / 45).rounded()) % points.count]
    }

    private static func precipitation(_ forecast: Forecast, formatter: WeatherFormatter) -> PrecipitationContent {
        let today = forecast.today.map { formatter.precipitation(millimeters: $0.precipitationSum) } ?? "—"
        let nextWet = forecast.daily.dropFirst().first { $0.precipitationSum >= wetDayThreshold }
        let outlook: String =
            if let nextWet {
                .ForecastUI.forecastPrecipitationNext(
                    nextWet.date.formatted(Date.FormatStyle(timeZone: forecast.timeZone).weekday(.wide)),
                )
            } else {
                .ForecastUI.forecastPrecipitationNone
            }
        return PrecipitationContent(today: today, outlook: outlook)
    }

    private static func details(_ forecast: Forecast, formatter: WeatherFormatter, timeZone: TimeZone) -> [Detail] {
        let current = forecast.current
        let hour = forecast.hourly.first
        let today = forecast.today
        var details = [
            Detail(id: "feels", title: .ForecastUI.forecastFeelsLike, value: formatter.temperature(celsius: current.apparentTemperature)),
            Detail(id: "humidity", title: .ForecastUI.forecastHumidity, value: "\(Int(current.humidity.rounded()))%"),
            Detail(id: "pressure", title: .ForecastUI.forecastPressure, value: formatter.pressure(hectopascals: current.pressure)),
        ]
        if let hour {
            details.append(Detail(id: "uv", title: .ForecastUI.forecastUvIndex, value: "\(Int(hour.uvIndex.rounded()))"))
            details.append(Detail(id: "visibility", title: .ForecastUI.forecastVisibility, value: formatter.distance(meters: hour.visibility)))
        }
        if let sunrise = today?.sunrise {
            details.append(Detail(id: "sunrise", title: .ForecastUI.forecastSunrise, value: formatter.time(sunrise, in: timeZone)))
        }
        if let sunset = today?.sunset {
            details.append(Detail(id: "sunset", title: .ForecastUI.forecastSunset, value: formatter.time(sunset, in: timeZone)))
        }
        return details
    }
}
