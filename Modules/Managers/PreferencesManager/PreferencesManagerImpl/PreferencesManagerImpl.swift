//
//  PreferencesManagerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import Foundation
import Inject
import Logging
import PreferencesManager
import SwiftAsyncEx

@MainActor
public final class PreferencesManagerImpl: PreferencesManager {
    private let appEnvironment: AppEnvironment = Inject()
    private let measurementSystem: Locale.MeasurementSystem

    // One persistent property per setting, in the user's property store.
    private let storedTemperatureUnit: PersistentProperty<TemperatureUnitPreference>
    private let storedWindSpeedUnit: PersistentProperty<WindSpeedUnit>
    private let storedPrecipitationUnit: PersistentProperty<PrecipitationUnit>
    private let storedPressureUnit: PersistentProperty<PressureUnit>
    private let storedDistanceUnit: PersistentProperty<DistanceUnit>
    private let storedTimeFormat: PersistentProperty<TimeFormat>
    private let storedAirQualityScale: PersistentProperty<AirQualityScale>

    public private(set) lazy var temperatureUnit: any PropertyProtocol<TemperatureUnitPreference> =
        Property(mirroring: storedTemperatureUnit)
    public private(set) lazy var windSpeedUnit: any PropertyProtocol<WindSpeedUnit> = Property(mirroring: storedWindSpeedUnit)
    public private(set) lazy var precipitationUnit: any PropertyProtocol<PrecipitationUnit> =
        Property(mirroring: storedPrecipitationUnit)
    public private(set) lazy var pressureUnit: any PropertyProtocol<PressureUnit> = Property(mirroring: storedPressureUnit)
    public private(set) lazy var distanceUnit: any PropertyProtocol<DistanceUnit> = Property(mirroring: storedDistanceUnit)
    public private(set) lazy var timeFormat: any PropertyProtocol<TimeFormat> = Property(mirroring: storedTimeFormat)
    public private(set) lazy var airQualityScale: any PropertyProtocol<AirQualityScale> =
        Property(mirroring: storedAirQualityScale)

    public private(set) lazy var resolvedTemperatureUnit: any PropertyProtocol<TemperatureUnit> =
        Property(tracking: { [storedTemperatureUnit, measurementSystem] in
            Self.resolve(storedTemperatureUnit.value, measurementSystem: measurementSystem)
        })

    public private(set) lazy var unitSettings: any PropertyProtocol<UnitSettings> =
        Property(tracking: { [weak self] in
            self?.currentUnitSettings ?? UnitSettings(defaults: RegionDefaults(measurementSystem: .metric))
        })

    /// - Parameter measurementSystem: The region whose defaults apply. Tests
    ///   pass one; the app uses the device's.
    public init(measurementSystem: Locale.MeasurementSystem = Locale.current.measurementSystem) {
        self.measurementSystem = measurementSystem
        let defaults = RegionDefaults(measurementSystem: measurementSystem)
        let store = appEnvironment.propertyFileStore
        self.storedTemperatureUnit = .init(storageEngine: store, key: "PreferenceTemperatureUnit", defaultValue: .system)
        self.storedWindSpeedUnit = .init(storageEngine: store, key: "PreferenceWindSpeedUnit", defaultValue: defaults.windSpeed)
        self.storedPrecipitationUnit = .init(storageEngine: store, key: "PreferencePrecipitationUnit", defaultValue: defaults.precipitation)
        self.storedPressureUnit = .init(storageEngine: store, key: "PreferencePressureUnit", defaultValue: defaults.pressure)
        self.storedDistanceUnit = .init(storageEngine: store, key: "PreferenceDistanceUnit", defaultValue: defaults.distance)
        self.storedTimeFormat = .init(storageEngine: store, key: "PreferenceTimeFormat", defaultValue: .system)
        self.storedAirQualityScale = .init(storageEngine: store, key: "PreferenceAirQualityScale", defaultValue: defaults.airQualityScale)
    }

    private var currentUnitSettings: UnitSettings {
        UnitSettings(
            temperature: Self.resolve(storedTemperatureUnit.value, measurementSystem: measurementSystem),
            windSpeed: storedWindSpeedUnit.value,
            precipitation: storedPrecipitationUnit.value,
            pressure: storedPressureUnit.value,
            distance: storedDistanceUnit.value,
            timeFormat: storedTimeFormat.value,
            airQualityScale: storedAirQualityScale.value,
        )
    }

    private static func resolve(_ preference: TemperatureUnitPreference, measurementSystem: Locale.MeasurementSystem) -> TemperatureUnit {
        switch preference {
        case .celsius: .celsius
        case .fahrenheit: .fahrenheit
        case .system: RegionDefaults(measurementSystem: measurementSystem).temperature
        }
    }

    // MARK: Setters

    public func setTemperatureUnit(_ unit: TemperatureUnitPreference) {
        storedTemperatureUnit.value = unit
    }

    public func setWindSpeedUnit(_ unit: WindSpeedUnit) {
        storedWindSpeedUnit.value = unit
    }

    public func setPrecipitationUnit(_ unit: PrecipitationUnit) {
        storedPrecipitationUnit.value = unit
    }

    public func setPressureUnit(_ unit: PressureUnit) {
        storedPressureUnit.value = unit
    }

    public func setDistanceUnit(_ unit: DistanceUnit) {
        storedDistanceUnit.value = unit
    }

    public func setTimeFormat(_ format: TimeFormat) {
        storedTimeFormat.value = format
    }

    public func setAirQualityScale(_ scale: AirQualityScale) {
        storedAirQualityScale.value = scale
    }

    public func restoreDefaults() {
        Log(.preferences, .info, "Restoring default units")
        let defaults = RegionDefaults(measurementSystem: measurementSystem)
        storedTemperatureUnit.value = .system
        storedWindSpeedUnit.value = defaults.windSpeed
        storedPrecipitationUnit.value = defaults.precipitation
        storedPressureUnit.value = defaults.pressure
        storedDistanceUnit.value = defaults.distance
        storedTimeFormat.value = .system
        storedAirQualityScale.value = defaults.airQualityScale
    }
}

extension UnitSettings {
    init(defaults: RegionDefaults) {
        self.init(
            temperature: defaults.temperature,
            windSpeed: defaults.windSpeed,
            precipitation: defaults.precipitation,
            pressure: defaults.pressure,
            distance: defaults.distance,
            timeFormat: .system,
            airQualityScale: defaults.airQualityScale,
        )
    }
}
