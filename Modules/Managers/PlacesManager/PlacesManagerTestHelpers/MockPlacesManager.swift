//
//  MockPlacesManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import CocoaEx
import DeviceLocationManager
import Foundation
import PlacesManager
import SwiftAsyncEx

@MainActor
public final class MockPlacesManager: PlacesManager {
    public let mutablePlaces: MutableProperty<[Place]>
    public let mutableHasLoaded = MutableProperty(true)
    public let mutableLocationAuthorization = MutableProperty(LocationAuthorization.notDetermined)
    public let mutableSavedGeocodingIds = MutableProperty<Set<Int64>>([])

    public var searchResults: Result<[PlaceSearchResult], PlacesError> = .success([])
    public var addError: PlacesError?
    public private(set) var searches: [String] = []
    public private(set) var added: [PlaceSearchResult] = []
    public private(set) var deleted: [String] = []
    public private(set) var authorizationRequests = 0

    public private(set) lazy var places = Property(mirroring: mutablePlaces)
    public private(set) lazy var hasLoaded = Property(mirroring: mutableHasLoaded)
    public private(set) lazy var locationAuthorization =
        Property(mirroring: mutableLocationAuthorization)
    public private(set) lazy var savedGeocodingIds = Property(mirroring: mutableSavedGeocodingIds)

    public init(places: [Place] = []) {
        self.mutablePlaces = MutableProperty(places)
    }

    public func requestLocationAuthorizationIfNeeded() {
        authorizationRequests += 1
    }

    public func search(_ query: String) async throws(PlacesError) -> [PlaceSearchResult] {
        searches.append(query)
        return try searchResults.get()
    }

    @discardableResult
    public func add(_ result: PlaceSearchResult) async throws(PlacesError) -> Place {
        if let addError {
            throw addError
        }

        added.append(result)
        let place = Place(
            id: "added-\(result.id)",
            name: result.name,
            region: result.region,
            country: result.country,
            latitude: result.latitude,
            longitude: result.longitude,
            timeZone: result.timeZone,
            isCurrentLocation: false,
        )
        mutablePlaces.value.append(place)
        mutableSavedGeocodingIds.value.insert(result.id)
        return place
    }

    public func delete(placeId: String) async throws(PlacesError) {
        deleted.append(placeId)
        mutablePlaces.value.removeAll { $0.id == placeId }
    }

    public func moveSavedPlaces(fromOffsets source: IndexSet, toOffset destination: Int) async throws(PlacesError) {
        let current = mutablePlaces.value.filter(\.isCurrentLocation)
        var saved = mutablePlaces.value.filter { !$0.isCurrentLocation }
        saved.moveElements(fromOffsets: source, toOffset: destination)
        mutablePlaces.value = current + saved
    }
}

public extension Place {
    static func testPlace(
        id: String = UUID().lowercaseUUIDString,
        name: String = "Springfield",
        isCurrentLocation: Bool = false,
    ) -> Place {
        Place(
            id: id,
            name: name,
            region: "Region",
            country: "Country",
            latitude: 40,
            longitude: -100,
            timeZone: TimeZone(identifier: "America/Chicago"),
            isCurrentLocation: isCurrentLocation,
        )
    }
}

public extension PlaceSearchResult {
    static func testResult(id: Int64 = 1, name: String = "Springfield") -> PlaceSearchResult {
        PlaceSearchResult(
            id: id,
            name: name,
            region: "Illinois",
            country: "United States",
            latitude: 39.8,
            longitude: -89.6,
            timeZone: TimeZone(identifier: "America/Chicago"),
        )
    }
}
