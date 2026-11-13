//
//  UnitsScreenImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import Inject
import PreferencesManager
import SettingsUI
import SettingsUIResources
import SFSafeSymbols
import SwiftAsyncEx
import SwiftUIEx
import UIKit

@MainActor
public final class UnitsScreenImpl: HostingScreen<UnitsScreenModel, UnitsView>, UnitsScreen {
    public convenience init(builder: UnitsScreenBuilder) {
        self.init(controllerModel: UnitsScreenModel())
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        title = String.SettingsUI.unitsTitle
        let done = UIBarButtonItem(
            image: UIImage(systemSymbol: .checkmark),
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            },
        )
        done.accessibilityLabel = String.SettingsUI.unitsDone
        navigationItem.rightBarButtonItem = done
    }
}

@MainActor
public final class UnitsScreenModel: HostingScreenModel {
    public weak var viewController: UIViewController?
    public private(set) lazy var viewModel = UnitsViewModel(
        settings: preferencesManager.unitSettings,
        temperaturePreference: preferencesManager.temperatureUnit,
        systemTemperatureUnit: .constant(RegionDefaults(measurementSystem: Locale.current.measurementSystem).temperature),
        changeTask: .weak(self) { `self`, change in
            self.apply(change)
        },
    )

    private let preferencesManager: PreferencesManager = Inject()

    public init() {}

    /// Every change goes straight to the manager; the view updates when the
    /// manager's properties do, so there is one source of truth.
    private func apply(_ change: UnitsViewModel.Change) {
        switch change {
        case let .temperature(preference): preferencesManager.setTemperatureUnit(preference)
        case let .windSpeed(unit): preferencesManager.setWindSpeedUnit(unit)
        case let .precipitation(unit): preferencesManager.setPrecipitationUnit(unit)
        case let .pressure(unit): preferencesManager.setPressureUnit(unit)
        case let .distance(unit): preferencesManager.setDistanceUnit(unit)
        case let .timeFormat(format): preferencesManager.setTimeFormat(format)
        case let .airQualityScale(scale): preferencesManager.setAirQualityScale(scale)
        case .restoreDefaults: preferencesManager.restoreDefaults()
        }
    }
}
