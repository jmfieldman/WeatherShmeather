//
//  PlacesManagerImplTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import AppEnvironmentTestHelpers
import DeviceLocationManager
import DeviceLocationManagerTestHelpers
import Foundation
import Inject
import NetworkManager
import NetworkManagerTestHelpers
import PlacesManager
@testable import PlacesManagerImpl
import PlacesManagerTestHelpers
import SlateManager
import SlateManagerTestHelpers
import Testing

@MainActor
struct PlacesManagerImplTests {
    private let network = MockNetworkManager()
    private let location = MockDeviceLocationManager()

    private func makeManager(userId: String? = "tester") -> PlacesManagerImpl {
        let environment = AppEnvironment.test(userId: userId)
        let slate = MockSlateManager()
        InjectionManager.register(AppEnvironment.self) { environment }
        InjectionManager.register(NetworkManager.self) { [network] in network }
        InjectionManager.register(SlateManager.self) { slate }
        InjectionManager.register(DeviceLocationManager.self) { [location] in location }
        InjectionManager.resetCurrentContainer()
        return PlacesManagerImpl()
    }

    /// Slate streams emit after a write lands, not during it.
    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0 ..< 100 where !condition() {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func loadsEmpty() async {
        let manager = makeManager()

        await waitUntil { manager.hasLoaded.value }

        #expect(manager.hasLoaded.value)
        #expect(manager.places.value.isEmpty)
    }

    @Test func addAppendsInOrder() async throws {
        let manager = makeManager()

        try await manager.add(.testResult(id: 1, name: "Austin"))
        try await manager.add(.testResult(id: 2, name: "Boston"))
        await waitUntil { manager.places.value.count == 2 }

        #expect(manager.places.value.map(\.name) == ["Austin", "Boston"])
        #expect(manager.savedGeocodingIds.value == [1, 2])
    }

    @Test func addingTheSameResultTwiceFails() async throws {
        let manager = makeManager()
        try await manager.add(.testResult(id: 1))
        await waitUntil { manager.savedGeocodingIds.value.contains(1) }

        await #expect(throws: PlacesError.alreadySaved) {
            try await manager.add(.testResult(id: 1))
        }
    }

    @Test func deleteAndMove() async throws {
        let manager = makeManager()
        let austin = try await manager.add(.testResult(id: 1, name: "Austin"))
        try await manager.add(.testResult(id: 2, name: "Boston"))
        try await manager.add(.testResult(id: 3, name: "Chicago"))
        await waitUntil { manager.places.value.count == 3 }

        try await manager.moveSavedPlaces(fromOffsets: [2], toOffset: 0)
        await waitUntil { manager.places.value.first?.name == "Chicago" }
        #expect(manager.places.value.map(\.name) == ["Chicago", "Austin", "Boston"])

        try await manager.delete(placeId: austin.id)
        await waitUntil { manager.places.value.count == 2 }
        #expect(manager.places.value.map(\.name) == ["Chicago", "Boston"])
    }

    @Test func currentLocationIsFirstAndIgnoresJitter() async throws {
        location.defaultPlaceName = "Here"
        let manager = makeManager()
        try await manager.add(.testResult(id: 1, name: "Austin"))

        location.mutableAuthorization.value = .authorized
        location.mutableLocation.value = Coordinate(latitude: 40, longitude: -100)
        await waitUntil { manager.places.value.first?.isCurrentLocation == true }
        #expect(manager.places.value.map(\.name) == ["Here", "Austin"])

        // A few hundred meters isn't a move.
        location.defaultPlaceName = "Elsewhere"
        location.mutableLocation.value = Coordinate(latitude: 40.002, longitude: -100)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(manager.places.value.first?.name == "Here")

        // Tens of kilometers is.
        location.mutableLocation.value = Coordinate(latitude: 40.5, longitude: -100)
        await waitUntil { manager.places.value.first?.name == "Elsewhere" }
        #expect(manager.places.value.first?.name == "Elsewhere")
    }

    @Test func denyingLocationRemovesTheCurrentLocation() async {
        location.defaultPlaceName = "Here"
        let manager = makeManager()
        location.mutableAuthorization.value = .authorized
        location.mutableLocation.value = Coordinate(latitude: 40, longitude: -100)
        await waitUntil { !manager.places.value.isEmpty }

        location.mutableAuthorization.value = .denied
        await waitUntil { manager.places.value.isEmpty }

        #expect(manager.places.value.isEmpty)
    }

    private func response(_ json: String) throws -> SearchPlacesResponse {
        try JSONDecoder().decode(SearchPlacesResponse.self, from: Data(json.utf8))
    }

    @Test func searchMapsResults() async throws {
        let berlin = try response(
            #"{"results":[{"id":2950159,"name":"Berlin","latitude":52.52,"longitude":13.41,"timezone":"Europe/Berlin","country":"Germany","admin1":"Land Berlin"}]}"#,
        )
        network.stub(SearchPlacesResource.self) { _, request in
            #expect(request.name == "Berlin")
            return berlin
        }
        let manager = makeManager()

        let results = try await manager.search("  Berlin ")

        #expect(results.map(\.name) == ["Berlin"])
        #expect(results.first?.detail == "Land Berlin, Germany")
        #expect(results.first?.timeZone?.identifier == "Europe/Berlin")
    }

    @Test func searchWithNoMatchesIsEmpty() async throws {
        let empty = try response(#"{"generationtime_ms":0.5}"#)
        network.stub(SearchPlacesResource.self) { _, _ in empty }
        let manager = makeManager()

        #expect(try await manager.search("zzzz").isEmpty)
    }
}

struct MoveElementsTests {
    @Test(arguments: [
        ([0], 3, ["b", "c", "a", "d"]),
        ([3], 0, ["d", "a", "b", "c"]),
        ([1, 2], 4, ["a", "d", "b", "c"]),
        ([2], 1, ["a", "c", "b", "d"]),
    ] as [(IndexSet, Int, [String])])
    func matchesOnMoveSemantics(source: IndexSet, destination: Int, expected: [String]) {
        var array = ["a", "b", "c", "d"]
        array.moveElements(fromOffsets: source, toOffset: destination)
        #expect(array == expected)
    }
}
