//
//  PlacesManagerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import CocoaEx
import DeviceLocationManager
import Foundation
import Inject
import Logging
import NetworkManager
import PlacesManager
import PlacesModels
import Slate
import SlateManager
import SwiftAsyncEx

/// The fixed id of the one current-location row.
let kCurrentLocationPlaceId = "current-location"

/// How far the device must move before the current-location row is
/// overwritten, so small GPS jitter doesn't rename the place or refetch its
/// weather.
let kCurrentLocationMoveThreshold: Double = 1000

private let kSearchResultCount = 20

@MainActor
public final class PlacesManagerImpl: PlacesManager {
    private let appEnvironment: AppEnvironment = Inject()
    private let networkManager: NetworkManager = Inject()
    private let slateManager: SlateManager = Inject()
    private let deviceLocationManager: DeviceLocationManager = Inject()

    private let slate: Slate<PlacesSlateSchema>

    /// Every row, current location first. Slate re-emits after each write,
    /// so the manager never republishes by hand.
    private let stream: SlateStream<StoredPlace>

    private let mutablePlaces = MutableProperty<[Place]>([])
    public private(set) lazy var places = Property(mirroring: mutablePlaces)

    private let mutableHasLoaded = MutableProperty(false)
    public private(set) lazy var hasLoaded = Property(mirroring: mutableHasLoaded)

    private let mutableSavedGeocodingIds = MutableProperty<Set<Int64>>([])
    public private(set) lazy var savedGeocodingIds =
        Property(mirroring: mutableSavedGeocodingIds)

    public var locationAuthorization: Property<LocationAuthorization> {
        deviceLocationManager.authorization
    }

    public init() {
        self.slate = slateManager.provide(for: PlacesSlateSchema.self)
        self.stream = slate.stream(
            StoredPlace.self,
            sort: [.desc(\.isCurrentLocation), .asc(\.sortOrder)],
        )

        Task.observe(bindTo: self) { [stream] in
            (stream.state, stream.values)
        } perform: { [weak self] state, rows in
            self?.publish(rows, isReady: state == .ready)
        }

        // Signed out, there's no list to keep current.
        guard appEnvironment.userId != nil else {
            return
        }

        observeDeviceLocation()
    }

    // MARK: Publishing

    private func publish(_ rows: [StoredPlace], isReady: Bool) {
        let places = rows.map(Place.init(stored:))
        if mutablePlaces.value != places {
            mutablePlaces.value = places
        }

        let geocodingIds = Set(rows.compactMap(\.geocodingId))
        if mutableSavedGeocodingIds.value != geocodingIds {
            mutableSavedGeocodingIds.value = geocodingIds
        }

        if isReady, !mutableHasLoaded.value {
            mutableHasLoaded.value = true
        }
    }

    // MARK: Current location

    private func observeDeviceLocation() {
        Task.observe(bindTo: self) { [deviceLocationManager] in
            deviceLocationManager.authorization.value
        } perform: { [weak self] authorization in
            // The current location shows only while permission is granted.
            if authorization != .authorized {
                await self?.removeCurrentLocation()
            }
        }

        Task.observe(bindTo: self) { [deviceLocationManager] in
            deviceLocationManager.location.value
        } perform: { [weak self] coordinate in
            if let coordinate {
                await self?.updateCurrentLocation(to: coordinate)
            }
        }
    }

    /// Overwrites the current-location row when the device has moved far
    /// enough, or creates it the first time there's a location.
    func updateCurrentLocation(to coordinate: Coordinate) async {
        let existing = try? await slate.one(StoredPlace.self, where: \.placeId == kCurrentLocationPlaceId)
        if let existing {
            let stored = Coordinate(latitude: existing.latitude, longitude: existing.longitude)
            guard stored.distance(to: coordinate) >= kCurrentLocationMoveThreshold else {
                return
            }
        }

        let name = await deviceLocationManager.placeName(for: coordinate) ?? existing?.name ?? ""
        let timeZoneIdentifier = TimeZone.current.identifier
        Log(.places, .info, "Current location moved; updating its row")
        do {
            try await slate.mutate { context in
                let row = try context[DatabaseStoredPlace.self].firstOrCreate(\.placeId, kCurrentLocationPlaceId)
                row.name = name
                row.region = nil
                row.country = nil
                row.latitude = coordinate.latitude
                row.longitude = coordinate.longitude
                row.timeZoneIdentifier = timeZoneIdentifier
                row.sortOrder = 0
                row.isCurrentLocation = true
                row.geocodingId = nil
            }
        } catch {
            Log(.places, .error, "Couldn't save the current location: \(error.localizedDescription)")
        }
    }

    private func removeCurrentLocation() async {
        do {
            try await slate.mutate { context in
                _ = try context[DatabaseStoredPlace.self].delete(where: \.placeId == kCurrentLocationPlaceId)
            }
        } catch {
            Log(.places, .error, "Couldn't remove the current location: \(error.localizedDescription)")
        }
    }

    public func requestLocationAuthorizationIfNeeded() {
        deviceLocationManager.requestAuthorizationIfNeeded()
    }

    // MARK: Search

    public func search(_ query: String) async throws(PlacesError) -> [PlaceSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let request = SearchPlacesRequest(
            name: trimmed,
            count: kSearchResultCount,
            language: Locale.current.language.languageCode?.identifier ?? "en",
        )
        do {
            let response = try await networkManager.request(resource: SearchPlacesResource(), with: request)
            return (response.results ?? []).map(PlaceSearchResult.init(result:))
        } catch {
            throw .searchFailed
        }
    }

    // MARK: Editing

    @discardableResult
    public func add(_ result: PlaceSearchResult) async throws(PlacesError) -> Place {
        guard !mutableSavedGeocodingIds.value.contains(result.id) else {
            throw .alreadySaved
        }

        let placeId = UUID().lowercaseUUIDString
        do {
            let stored = try await slate.mutate { context in
                let table = context[DatabaseStoredPlace.self]
                let lastOrder = try table.many(where: \.isCurrentLocation == false).map(\.sortOrder).max() ?? 0
                let row = context.create(DatabaseStoredPlace.self)
                row.placeId = placeId
                row.name = result.name
                row.region = result.region
                row.country = result.country
                row.latitude = result.latitude
                row.longitude = result.longitude
                row.timeZoneIdentifier = result.timeZone?.identifier
                row.sortOrder = lastOrder + 1
                row.isCurrentLocation = false
                row.geocodingId = result.id
                return context.immutable(row)
            }
            Log(.places, .info, "Added a place")
            return Place(stored: stored)
        } catch {
            Log(.places, .error, "Couldn't add a place: \(error.localizedDescription)")
            throw .storageFailed
        }
    }

    public func delete(placeId: String) async throws(PlacesError) {
        guard placeId != kCurrentLocationPlaceId else {
            return
        }

        do {
            try await slate.mutate { context in
                _ = try context[DatabaseStoredPlace.self].delete(where: \.placeId == placeId)
            }
        } catch {
            Log(.places, .error, "Couldn't delete a place: \(error.localizedDescription)")
            throw .storageFailed
        }
    }

    public func moveSavedPlaces(fromOffsets source: IndexSet, toOffset destination: Int) async throws(PlacesError) {
        var ids = mutablePlaces.value.filter { !$0.isCurrentLocation }.map(\.id)
        ids.moveElements(fromOffsets: source, toOffset: destination)
        let order = ids

        do {
            try await slate.mutate { context in
                let rows = try context[DatabaseStoredPlace.self].dictionary(by: \.placeId)
                for (index, placeId) in order.enumerated() {
                    rows[placeId]?.sortOrder = Int64(index + 1)
                }
            }
        } catch {
            Log(.places, .error, "Couldn't reorder places: \(error.localizedDescription)")
            throw .storageFailed
        }
    }
}

extension Place {
    init(stored: StoredPlace) {
        self.init(
            id: stored.placeId,
            name: stored.name,
            region: stored.region,
            country: stored.country,
            latitude: stored.latitude,
            longitude: stored.longitude,
            timeZone: stored.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)),
            isCurrentLocation: stored.isCurrentLocation,
        )
    }
}
