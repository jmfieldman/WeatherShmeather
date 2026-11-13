//
//  PreferencesManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SwiftAsyncEx

/// The user's units and display settings, each its own persistent value.
///
/// Weather is always stored in metric. These settings only change how it's
/// shown, so changing one never refetches anything.
@MainActor
public protocol PreferencesManager: AnyObject, Sendable {
    var temperatureUnit: Property<TemperatureUnitPreference> { get }
    var windSpeedUnit: Property<WindSpeedUnit> { get }
    var precipitationUnit: Property<PrecipitationUnit> { get }
    var pressureUnit: Property<PressureUnit> { get }
    var distanceUnit: Property<DistanceUnit> { get }
    var timeFormat: Property<TimeFormat> { get }
    var airQualityScale: Property<AirQualityScale> { get }

    /// The temperature setting with "system" resolved for the device's region.
    var resolvedTemperatureUnit: Property<TemperatureUnit> { get }

    /// Every setting, resolved, derived from the ones above. Screens format
    /// with this, and update whenever any setting changes.
    var unitSettings: Property<UnitSettings> { get }

    func setTemperatureUnit(_ unit: TemperatureUnitPreference)
    func setWindSpeedUnit(_ unit: WindSpeedUnit)
    func setPrecipitationUnit(_ unit: PrecipitationUnit)
    func setPressureUnit(_ unit: PressureUnit)
    func setDistanceUnit(_ unit: DistanceUnit)
    func setTimeFormat(_ format: TimeFormat)
    func setAirQualityScale(_ scale: AirQualityScale)

    /// Returns every setting to its default for the device's region.
    func restoreDefaults()
}
