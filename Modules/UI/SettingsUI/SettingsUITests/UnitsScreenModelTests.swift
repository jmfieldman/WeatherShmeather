//
//  UnitsScreenModelTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import Inject
import PreferencesManager
import PreferencesManagerTestHelpers
import SettingsUIImpl
import Testing

@MainActor
struct UnitsScreenModelTests {
    private func makeModel(preferences: MockPreferencesManager) -> UnitsScreenModel {
        InjectionManager.register(PreferencesManager.self) { preferences }
        InjectionManager.resetCurrentContainer()
        return UnitsScreenModel()
    }

    @Test func changesGoToTheManager() {
        let preferences = MockPreferencesManager()
        let model = makeModel(preferences: preferences)

        model.viewModel.onChange(.temperature(.fahrenheit))
        model.viewModel.onChange(.windSpeed(.knots))
        model.viewModel.onChange(.restoreDefaults)

        #expect(preferences.mutableTemperatureUnit.value == .fahrenheit)
        #expect(preferences.mutableWindSpeedUnit.value == .knots)
        #expect(preferences.restoreDefaultsCount == 1)
    }

    @Test func viewModelFollowsTheManager() async {
        let preferences = MockPreferencesManager()
        let model = makeModel(preferences: preferences)

        preferences.setPressureUnit(.inchesOfMercury)
        for _ in 0 ..< 50 where model.viewModel.settings.pressure != .inchesOfMercury {
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(model.viewModel.settings.pressure == .inchesOfMercury)
    }
}
