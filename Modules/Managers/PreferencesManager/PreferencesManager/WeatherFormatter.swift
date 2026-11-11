//
//  WeatherFormatter.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// Turns stored metric values into display strings in the user's units.
///
/// A plain value built from `UnitSettings`, so a screen model makes a new
/// one whenever settings change and passes strings, never raw numbers, to
/// its view.
public struct WeatherFormatter: Sendable {
    public let settings: UnitSettings
    public let locale: Locale

    public init(settings: UnitSettings, locale: Locale = .current) {
        self.settings = settings
        self.locale = locale
    }

    // MARK: Temperature

    /// A temperature in the user's unit, rounded to a whole degree.
    public func temperatureValue(celsius: Double) -> Double {
        switch settings.temperature {
        case .celsius: celsius
        case .fahrenheit: celsius * 9 / 5 + 32
        }
    }

    /// "82°". The unit is left implied, as weather apps do.
    public func temperature(celsius: Double) -> String {
        let rounded = Int(temperatureValue(celsius: celsius).rounded())
        return "\(rounded.formatted(.number.locale(locale)))°"
    }

    /// "°F" or "°C", for the one place that names the unit.
    public var temperatureUnitSymbol: String {
        switch settings.temperature {
        case .celsius: UnitTemperature.celsius.symbol
        case .fahrenheit: UnitTemperature.fahrenheit.symbol
        }
    }

    // MARK: Other units

    /// "12 mph", from km/h.
    public func windSpeed(kilometersPerHour: Double) -> String {
        let unit: UnitSpeed =
            switch settings.windSpeed {
            case .kilometersPerHour: .kilometersPerHour
            case .metersPerSecond: .metersPerSecond
            case .milesPerHour: .milesPerHour
            case .knots: .knots
            }
        let value = Measurement(value: kilometersPerHour, unit: UnitSpeed.kilometersPerHour).converted(to: unit).value
        return "\(Int(value.rounded()).formatted(.number.locale(locale))) \(unit.symbol)"
    }

    /// "0.12 in" or "3 mm", from millimeters.
    public func precipitation(millimeters: Double) -> String {
        switch settings.precipitation {
        case .millimeters:
            let text = millimeters.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))
            return "\(text) \(UnitLength.millimeters.symbol)"

        case .inches:
            let inches = Measurement(value: millimeters, unit: UnitLength.millimeters).converted(to: .inches).value
            let text = inches.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale))
            return "\(text) \(UnitLength.inches.symbol)"
        }
    }

    /// "29.92 inHg" or "1013 hPa", from hectopascals.
    public func pressure(hectopascals: Double) -> String {
        switch settings.pressure {
        case .hectopascals:
            return "\(Int(hectopascals.rounded()).formatted(.number.locale(locale))) \(UnitPressure.hectopascals.symbol)"
        case .inchesOfMercury:
            let inHg = Measurement(value: hectopascals, unit: UnitPressure.hectopascals).converted(to: .inchesOfMercury).value
            let text = inHg.formatted(.number.precision(.fractionLength(2)).locale(locale))
            return "\(text) \(UnitPressure.inchesOfMercury.symbol)"
        }
    }

    /// "10 mi" or "16 km", from meters.
    public func distance(meters: Double) -> String {
        let unit: UnitLength = settings.distance == .miles ? .miles : .kilometers
        let value = Measurement(value: meters, unit: UnitLength.meters).converted(to: unit).value
        let text = value.formatted(.number.precision(.fractionLength(0 ... (value < 10 ? 1 : 0))).locale(locale))
        return "\(text) \(unit.symbol)"
    }

    // MARK: Time

    /// "3 PM" or "15", for an hourly column, in the place's time zone.
    public func hour(_ date: Date, in timeZone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(locale: timeLocale, timeZone: timeZone).hour())
    }

    /// "3:32 PM" or "15:32", in the place's time zone.
    public func time(_ date: Date, in timeZone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(locale: timeLocale, timeZone: timeZone).hour().minute())
    }

    /// The locale with its hour cycle overridden when the user chose a clock,
    /// which is how a format style is told to use 12 or 24 hours.
    private var timeLocale: Locale {
        var components = Locale.Components(locale: locale)
        switch settings.timeFormat {
        case .system: return locale
        case .twelveHour: components.hourCycle = .oneToTwelve
        case .twentyFourHour: components.hourCycle = .zeroToTwentyThree
        }
        return Locale(components: components)
    }
}
