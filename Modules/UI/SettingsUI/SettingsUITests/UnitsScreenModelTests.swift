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

    @Test func changesGoToTheManager() async throws {
        let preferences = MockPreferencesManager()
        let model = makeModel(preferences: preferences)

        try await model.viewModel.changeTask.run(.temperature(.fahrenheit))
        try await model.viewModel.changeTask.run(.windSpeed(.knots))
        try await model.viewModel.changeTask.run(.restoreDefaults)

        #expect(preferences.mutableTemperatureUnit.value == .fahrenheit)
        #expect(preferences.mutableWindSpeedUnit.value == .knots)
        #expect(preferences.restoreDefaultsCount == 1)
    }

    @Test func viewModelFollowsTheManager() async {
        let preferences = MockPreferencesManager()
        let model = makeModel(preferences: preferences)

        preferences.setPressureUnit(.inchesOfMercury)
        for _ in 0 ..< 50 where model.viewModel.settings.value.pressure != .inchesOfMercury {
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(model.viewModel.settings.value.pressure == .inchesOfMercury)
    }
}
