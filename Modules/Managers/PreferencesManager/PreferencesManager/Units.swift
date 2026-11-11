//
//  Units.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// The temperature setting, which can defer to the device's region.
public enum TemperatureUnitPreference: String, Codable, Sendable, CaseIterable {
    case system
    case celsius
    case fahrenheit
}

/// A temperature unit after "system" has been resolved.
public enum TemperatureUnit: String, Codable, Sendable, CaseIterable {
    case celsius
    case fahrenheit
}

public enum WindSpeedUnit: String, Codable, Sendable, CaseIterable {
    case kilometersPerHour
    case metersPerSecond
    case milesPerHour
    case knots
}

public enum PrecipitationUnit: String, Codable, Sendable, CaseIterable {
    case millimeters
    case inches
}

public enum PressureUnit: String, Codable, Sendable, CaseIterable {
    case hectopascals
    case inchesOfMercury
}

public enum DistanceUnit: String, Codable, Sendable, CaseIterable {
    case kilometers
    case miles
}

public enum TimeFormat: String, Codable, Sendable, CaseIterable {
    case system
    case twelveHour
    case twentyFourHour
}

public enum AirQualityScale: String, Codable, Sendable, CaseIterable {
    case unitedStates
    case european
}

/// Every display setting, resolved, in one value: what a formatter needs.
public struct UnitSettings: Hashable, Sendable {
    public var temperature: TemperatureUnit
    public var windSpeed: WindSpeedUnit
    public var precipitation: PrecipitationUnit
    public var pressure: PressureUnit
    public var distance: DistanceUnit
    public var timeFormat: TimeFormat
    public var airQualityScale: AirQualityScale

    public init(
        temperature: TemperatureUnit,
        windSpeed: WindSpeedUnit,
        precipitation: PrecipitationUnit,
        pressure: PressureUnit,
        distance: DistanceUnit,
        timeFormat: TimeFormat,
        airQualityScale: AirQualityScale,
    ) {
        self.temperature = temperature
        self.windSpeed = windSpeed
        self.precipitation = precipitation
        self.pressure = pressure
        self.distance = distance
        self.timeFormat = timeFormat
        self.airQualityScale = airQualityScale
    }
}

/// The defaults for a measurement system: what a new user starts with, and
/// what Restore Defaults returns to.
public struct RegionDefaults: Sendable, Equatable {
    public let temperature: TemperatureUnit
    public let windSpeed: WindSpeedUnit
    public let precipitation: PrecipitationUnit
    public let pressure: PressureUnit
    public let distance: DistanceUnit
    public let airQualityScale: AirQualityScale

    public init(measurementSystem: Locale.MeasurementSystem) {
        switch measurementSystem {
        case .us:
            self.temperature = .fahrenheit
            self.windSpeed = .milesPerHour
            self.precipitation = .inches
            self.pressure = .inchesOfMercury
            self.distance = .miles
            self.airQualityScale = .unitedStates

        case .uk:
            self.temperature = .celsius
            self.windSpeed = .milesPerHour
            self.precipitation = .millimeters
            self.pressure = .hectopascals
            self.distance = .miles
            self.airQualityScale = .european

        default:
            self.temperature = .celsius
            self.windSpeed = .kilometersPerHour
            self.precipitation = .millimeters
            self.pressure = .hectopascals
            self.distance = .kilometers
            self.airQualityScale = .european
        }
    }
}
