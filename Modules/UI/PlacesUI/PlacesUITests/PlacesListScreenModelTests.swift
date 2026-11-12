//
//  PlacesListScreenModelTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import DeviceLocationManager
import ForecastManager
import ForecastManagerTestHelpers
import Inject
import PlacesManager
import PlacesManagerTestHelpers
@testable import PlacesUIImpl
import PreferencesManager
import PreferencesManagerTestHelpers
import SessionManager
import SessionManagerTestHelpers
import Testing

@MainActor
struct PlacesListScreenModelTests {
    /// Starts with no places, so the first load opens no pager.
    private func makeModel(places: MockPlacesManager) -> PlacesListScreenModel {
        InjectionManager.register(PlacesManager.self) { places }
        InjectionManager.register(SessionManager.self) { MockSessionManager() }
        InjectionManager.register(PreferencesManager.self) { MockPreferencesManager() }
        InjectionManager.register(ForecastManager.self) { MockForecastManager() }
        InjectionManager.resetCurrentContainer()
        return PlacesListScreenModel()
    }

    @Test func theListDoesNotAskForLocationOnItsOwn() {
        let places = MockPlacesManager()
        let model = makeModel(places: places)

        model.screenDidAppear()

        #expect(places.authorizationRequests == 0)
    }

    @Test func searchOffersCurrentLocationOnlyWithoutPermission() async {
        let places = MockPlacesManager()
        let model = makeModel(places: places)
        #expect(model.viewModel.showsCurrentLocation.value)

        places.mutableLocationAuthorization.value = .authorized
        await settle { !model.viewModel.showsCurrentLocation.value }

        #expect(!model.viewModel.showsCurrentLocation.value)
    }

    @Test func theRowAsksForPermissionFirst() async throws {
        let places = MockPlacesManager()
        let model = makeModel(places: places)

        try await model.viewModel.beginSearchTask.run()
        try await model.viewModel.currentLocationTask.run()

        #expect(places.authorizationRequests == 1)
    }

    @Test func grantingPermissionClosesSearchAndScrollsToTheCard() async throws {
        let places = MockPlacesManager()
        let model = makeModel(places: places)
        try await model.viewModel.beginSearchTask.run()
        try await model.viewModel.currentLocationTask.run()

        places.mutableLocationAuthorization.value = .authorized
        await settle { !model.viewModel.isSearching.value }
        #expect(!model.viewModel.isSearching.value)

        // The card arrives once the first position is named.
        let here = Place.testPlace(id: "here", isCurrentLocation: true)
        places.mutablePlaces.value = [here]
        await settle { model.viewModel.scrollTarget.value == "here" }

        #expect(model.viewModel.scrollTarget.value == "here")
    }

    @Test func decliningPermissionLeavesSearchOpen() async throws {
        let places = MockPlacesManager()
        let model = makeModel(places: places)
        try await model.viewModel.beginSearchTask.run()
        try await model.viewModel.currentLocationTask.run()

        places.mutableLocationAuthorization.value = .denied
        await settle { false }

        #expect(model.viewModel.isSearching.value)
        #expect(model.viewModel.showsCurrentLocation.value)
    }

    @Test func afterADenialTheRowNoLongerPrompts() async throws {
        let places = MockPlacesManager()
        places.mutableLocationAuthorization.value = .denied
        let model = makeModel(places: places)

        // With no view controller the Settings alert has nowhere to go; what
        // matters is that the system prompt isn't requested again.
        try await model.viewModel.currentLocationTask.run()

        #expect(places.authorizationRequests == 0)
    }

    /// View model properties mirror the screen model's on a later main-actor
    /// turn, so wait (briefly) for the one under test to catch up.
    private func settle(_ condition: @MainActor () -> Bool) async {
        for _ in 0 ..< 20 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
