//
//  MockPreferencesManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import PreferencesManager
import SwiftAsyncEx

@MainActor
public final class MockPreferencesManager: PreferencesManager {
    public let mutableTemperatureUnit = MutableProperty(TemperatureUnitPreference.celsius)
    public let mutableWindSpeedUnit = MutableProperty(WindSpeedUnit.kilometersPerHour)
    public let mutablePrecipitationUnit = MutableProperty(PrecipitationUnit.millimeters)
    public let mutablePressureUnit = MutableProperty(PressureUnit.hectopascals)
    public let mutableDistanceUnit = MutableProperty(DistanceUnit.kilometers)
    public let mutableTimeFormat = MutableProperty(TimeFormat.twentyFourHour)
    public let mutableAirQualityScale = MutableProperty(AirQualityScale.european)
    public private(set) var restoreDefaultsCount = 0

    public private(set) lazy var temperatureUnit: any PropertyProtocol<TemperatureUnitPreference> = Property(mirroring: mutableTemperatureUnit)
    public private(set) lazy var windSpeedUnit: any PropertyProtocol<WindSpeedUnit> = Property(mirroring: mutableWindSpeedUnit)
    public private(set) lazy var precipitationUnit: any PropertyProtocol<PrecipitationUnit> = Property(mirroring: mutablePrecipitationUnit)
    public private(set) lazy var pressureUnit: any PropertyProtocol<PressureUnit> = Property(mirroring: mutablePressureUnit)
    public private(set) lazy var distanceUnit: any PropertyProtocol<DistanceUnit> = Property(mirroring: mutableDistanceUnit)
    public private(set) lazy var timeFormat: any PropertyProtocol<TimeFormat> = Property(mirroring: mutableTimeFormat)
    public private(set) lazy var airQualityScale: any PropertyProtocol<AirQualityScale> = Property(mirroring: mutableAirQualityScale)

    public private(set) lazy var resolvedTemperatureUnit: any PropertyProtocol<TemperatureUnit> = Property(tracking: { [mutableTemperatureUnit] in
        mutableTemperatureUnit.value == .fahrenheit ? .fahrenheit : .celsius
    })

    public private(set) lazy var unitSettings: any PropertyProtocol<UnitSettings> = Property(tracking: { [weak self] in
        self?.currentSettings ?? .testSettings()
    })

    public init() {}

    private var currentSettings: UnitSettings {
        UnitSettings(
            temperature: mutableTemperatureUnit.value == .fahrenheit ? .fahrenheit : .celsius,
            windSpeed: mutableWindSpeedUnit.value,
            precipitation: mutablePrecipitationUnit.value,
            pressure: mutablePressureUnit.value,
            distance: mutableDistanceUnit.value,
            timeFormat: mutableTimeFormat.value,
            airQualityScale: mutableAirQualityScale.value,
        )
    }

    public func setTemperatureUnit(_ unit: TemperatureUnitPreference) {
        mutableTemperatureUnit.value = unit
    }

    public func setWindSpeedUnit(_ unit: WindSpeedUnit) {
        mutableWindSpeedUnit.value = unit
    }

    public func setPrecipitationUnit(_ unit: PrecipitationUnit) {
        mutablePrecipitationUnit.value = unit
    }

    public func setPressureUnit(_ unit: PressureUnit) {
        mutablePressureUnit.value = unit
    }

    public func setDistanceUnit(_ unit: DistanceUnit) {
        mutableDistanceUnit.value = unit
    }

    public func setTimeFormat(_ format: TimeFormat) {
        mutableTimeFormat.value = format
    }

    public func setAirQualityScale(_ scale: AirQualityScale) {
        mutableAirQualityScale.value = scale
    }

    public func restoreDefaults() {
        restoreDefaultsCount += 1
    }
}

public extension UnitSettings {
    /// Metric with a 24-hour clock, the most predictable for assertions.
    static func testSettings(
        temperature: TemperatureUnit = .celsius,
        windSpeed: WindSpeedUnit = .kilometersPerHour,
        precipitation: PrecipitationUnit = .millimeters,
        pressure: PressureUnit = .hectopascals,
        distance: DistanceUnit = .kilometers,
        timeFormat: TimeFormat = .twentyFourHour,
        airQualityScale: AirQualityScale = .european,
    ) -> UnitSettings {
        UnitSettings(
            temperature: temperature,
            windSpeed: windSpeed,
            precipitation: precipitation,
            pressure: pressure,
            distance: distance,
            timeFormat: timeFormat,
            airQualityScale: airQualityScale,
        )
    }
}
