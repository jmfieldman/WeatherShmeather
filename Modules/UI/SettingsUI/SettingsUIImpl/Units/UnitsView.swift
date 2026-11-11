//
//  UnitsView.swift
//  Copyright © 2026 WeatherShmeather.
//

import DesignSystem
import PreferencesManager
import SettingsUIResources
import SFSafeSymbols
import SwiftAsyncEx
import SwiftUI
import SwiftUIEx

@Observable @MainActor
public final class UnitsViewModel {
    public enum Change: Equatable, Sendable {
        case temperature(TemperatureUnitPreference)
        case windSpeed(WindSpeedUnit)
        case precipitation(PrecipitationUnit)
        case pressure(PressureUnit)
        case distance(DistanceUnit)
        case timeFormat(TimeFormat)
        case airQualityScale(AirQualityScale)
        case restoreDefaults
    }

    public let settings: Property<UnitSettings>
    public let temperaturePreference: Property<TemperatureUnitPreference>
    /// What "Use System Setting" resolves to on this device.
    public let systemTemperatureUnit: Property<TemperatureUnit>

    public let changeTask: SerialTask<Change, Void>

    public init(
        settings: Property<UnitSettings>,
        temperaturePreference: Property<TemperatureUnitPreference> = .constant(.system),
        systemTemperatureUnit: Property<TemperatureUnit> = .constant(.celsius),
        changeTask: SerialTask<Change, Void> = SerialTask { _ in },
    ) {
        self.settings = settings
        self.temperaturePreference = temperaturePreference
        self.systemTemperatureUnit = systemTemperatureUnit
        self.changeTask = changeTask
    }
}

public struct UnitsView: HostedView {
    let viewModel: UnitsViewModel

    public init(viewModel: UnitsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section(String.SettingsUI.unitsTemperatureHeader) {
                temperatureRow(.celsius, title: String.SettingsUI.unitsCelsius)
                temperatureRow(.fahrenheit, title: String.SettingsUI.unitsFahrenheit)
                temperatureRow(
                    .system,
                    title: String.SettingsUI.unitsSystemTemperature(viewModel.systemTemperatureUnit.value.symbol),
                )
            }

            Section(String.SettingsUI.unitsOtherHeader) {
                picker(String.SettingsUI.unitsWind, selection: viewModel.settings.value.windSpeed, change: UnitsViewModel.Change.windSpeed)
                picker(String.SettingsUI.unitsPrecipitation, selection: viewModel.settings.value.precipitation, change: UnitsViewModel.Change.precipitation)
                picker(String.SettingsUI.unitsPressure, selection: viewModel.settings.value.pressure, change: UnitsViewModel.Change.pressure)
                picker(String.SettingsUI.unitsDistance, selection: viewModel.settings.value.distance, change: UnitsViewModel.Change.distance)
            }

            Section(String.SettingsUI.unitsDisplayHeader) {
                picker(String.SettingsUI.unitsTimeFormat, selection: viewModel.settings.value.timeFormat, change: UnitsViewModel.Change.timeFormat)
                picker(
                    String.SettingsUI.unitsAirQualityScale,
                    selection: viewModel.settings.value.airQualityScale,
                    change: UnitsViewModel.Change.airQualityScale,
                )
            }

            Section {
                Button(String.SettingsUI.unitsRestoreDefaults) {
                    viewModel.changeTask.fire(.restoreDefaults)
                }
            } footer: {
                Text(String.SettingsUI.unitsRestoreFooter)
            }
        }
    }

    private func temperatureRow(_ preference: TemperatureUnitPreference, title: String) -> some View {
        Button {
            viewModel.changeTask.fire(.temperature(preference))
        } label: {
            HStack {
                Text(title)
                    .textStyle(.body)
                Spacer()
                if viewModel.temperaturePreference.value == preference {
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(DesignTokens.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.temperaturePreference.value == preference ? .isSelected : [])
    }

    /// A menu picker over every case of a unit, bound to the view model's
    /// current value and reporting changes as a `Change`.
    private func picker<Unit: UnitDisplayable>(
        _ title: String,
        selection: Unit,
        change: @escaping (Unit) -> UnitsViewModel.Change,
    ) -> some View {
        Picker(title, selection: Binding(get: { selection }, set: { viewModel.changeTask.fire(change($0)) })) {
            ForEach(Array(Unit.allCases), id: \.self) { unit in
                Text(unit.displayName).tag(unit)
            }
        }
        .pickerStyle(.menu)
    }
}

/// A unit enum that can list its cases by name in a picker.
protocol UnitDisplayable: CaseIterable, Hashable where AllCases: RandomAccessCollection {
    var displayName: String { get }
}

extension WindSpeedUnit: UnitDisplayable {
    var displayName: String {
        switch self {
        case .kilometersPerHour: .SettingsUI.unitKilometersPerHour
        case .metersPerSecond: .SettingsUI.unitMetersPerSecond
        case .milesPerHour: .SettingsUI.unitMilesPerHour
        case .knots: .SettingsUI.unitKnots
        }
    }
}

extension PrecipitationUnit: UnitDisplayable {
    var displayName: String {
        switch self {
        case .millimeters: .SettingsUI.unitMillimeters
        case .inches: .SettingsUI.unitInches
        }
    }
}

extension PressureUnit: UnitDisplayable {
    var displayName: String {
        switch self {
        case .hectopascals: .SettingsUI.unitHectopascals
        case .inchesOfMercury: .SettingsUI.unitInchesOfMercury
        }
    }
}

extension DistanceUnit: UnitDisplayable {
    var displayName: String {
        switch self {
        case .kilometers: .SettingsUI.unitKilometers
        case .miles: .SettingsUI.unitMiles
        }
    }
}

extension TimeFormat: UnitDisplayable {
    var displayName: String {
        switch self {
        case .system: .SettingsUI.timeFormatSystem
        case .twelveHour: .SettingsUI.timeFormatTwelveHour
        case .twentyFourHour: .SettingsUI.timeFormatTwentyFourHour
        }
    }
}

extension AirQualityScale: UnitDisplayable {
    var displayName: String {
        switch self {
        case .unitedStates: .SettingsUI.aqiScaleUnitedStates
        case .european: .SettingsUI.aqiScaleEuropean
        }
    }
}

extension TemperatureUnit {
    var symbol: String {
        switch self {
        case .celsius: UnitTemperature.celsius.symbol
        case .fahrenheit: UnitTemperature.fahrenheit.symbol
        }
    }
}

#Preview("Light") {
    UnitsView(viewModel: UnitsViewModel(
        settings: .constant(UnitSettings(
            temperature: .fahrenheit,
            windSpeed: .milesPerHour,
            precipitation: .inches,
            pressure: .inchesOfMercury,
            distance: .miles,
            timeFormat: .system,
            airQualityScale: .unitedStates,
        )),
        systemTemperatureUnit: .constant(.fahrenheit),
    ))
}
