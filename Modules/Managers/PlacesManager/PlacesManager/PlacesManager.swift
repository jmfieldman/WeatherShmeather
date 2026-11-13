//
//  PlacesManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import DeviceLocationManager
import Foundation
import SwiftAsyncEx

/// The user's places list: saved places in the user's order, with the
/// current location first while location permission allows it.
@MainActor
public protocol PlacesManager: AnyObject, Sendable {
    /// Every place, current location first. Republished after every write.
    var places: Property<[Place]> { get }

    /// False until the list has been read from disk once, so a screen can
    /// tell "no places" from "not loaded yet".
    var hasLoaded: Property<Bool> { get }

    /// Whether the current location can be shown.
    var locationAuthorization: Property<LocationAuthorization> { get }

    /// Asks for location permission if the user hasn't been asked.
    func requestLocationAuthorizationIfNeeded()

    /// Searches Open-Meteo's geocoding API by name.
    func search(_ query: String) async throws(PlacesError) -> [PlaceSearchResult]

    /// The geocoding ids already in the list, to mark saved search results.
    var savedGeocodingIds: Property<Set<Int64>> { get }

    /// Adds a search result to the end of the list and returns the new place.
    @discardableResult
    func add(_ result: PlaceSearchResult) async throws(PlacesError) -> Place

    /// Deletes a saved place. The current location can't be deleted.
    func delete(placeId: String) async throws(PlacesError)

    /// Moves a saved place, given the order of saved places only (the current
    /// location is never part of it).
    func moveSavedPlaces(fromOffsets source: IndexSet, toOffset destination: Int) async throws(PlacesError)
}

public extension Array {
    /// Moves the elements at `source` to `destination`, with the same meaning
    /// as SwiftUI's `onMove`: `destination` is an index in the array before
    /// the move.
    mutating func moveElements(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { self[$0] }
        let insertionIndex = destination - source.count(in: 0 ..< destination)
        for index in source.reversed() {
            remove(at: index)
        }
        insert(contentsOf: moving, at: insertionIndex)
    }
}
