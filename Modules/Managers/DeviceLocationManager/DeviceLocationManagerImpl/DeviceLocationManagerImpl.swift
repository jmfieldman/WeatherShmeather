//
//  DeviceLocationManagerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import CoreLocation
import DeviceLocationManager
import Foundation
import Inject
import Logging
import MapKit
import SwiftAsyncEx

@MainActor
public final class DeviceLocationManagerImpl: NSObject, DeviceLocationManager {
    private let appEnvironment: AppEnvironment = Inject()
    private let locationManager = CLLocationManager()

    private let mutableAuthorization = MutableProperty(LocationAuthorization.notDetermined)
    public private(set) lazy var authorization =
        Property(mirroring: mutableAuthorization)

    private let mutableLocation = MutableProperty<Coordinate?>(nil)
    public private(set) lazy var location = Property(mirroring: mutableLocation)

    /// The live-updates loop, running only while authorized. The bag is
    /// associated with this manager, so the loop ends with the session.
    private var updatesBag: TaskBag?

    override public init() {
        super.init()

        // Signed out, there are no places, so there's nothing to locate.
        guard appEnvironment.userId != nil else {
            return
        }

        locationManager.delegate = self
        apply(locationManager.authorizationStatus)
    }

    public func requestAuthorizationIfNeeded() {
        guard appEnvironment.userId != nil, locationManager.authorizationStatus == .notDetermined else {
            return
        }

        locationManager.requestWhenInUseAuthorization()
    }

    public func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        do {
            let mapItems = try await request.mapItems
            guard let item = mapItems.first else {
                return nil
            }

            return item.addressRepresentations?.cityName ?? item.name
        } catch {
            Log(.location, .warning, "Reverse geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func apply(_ status: CLAuthorizationStatus) {
        let authorization: LocationAuthorization =
            switch status {
            case .notDetermined: .notDetermined
            case .authorizedAlways, .authorizedWhenInUse: .authorized
            case .denied, .restricted: .denied
            @unknown default: .denied
            }

        mutableAuthorization.value = authorization
        if authorization == .authorized {
            startUpdates()
        } else {
            stopUpdates()
        }
    }

    private func startUpdates() {
        guard updatesBag == nil else {
            return
        }

        Log(.location, .info, "Starting location updates")
        let bag = TaskBag()
        updatesBag = bag
        Task { @MainActor [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.default) {
                    guard let self, !Task.isCancelled else {
                        return
                    }

                    if let location = update.location {
                        mutableLocation.value = Coordinate(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                        )
                    }
                }
            } catch {
                Log(.location, .warning, "Location updates ended: \(error.localizedDescription)")
            }
        }
        .bind(to: bag)
    }

    private func stopUpdates() {
        updatesBag?.cancelAll()
        updatesBag = nil
        mutableLocation.value = nil
    }
}

extension DeviceLocationManagerImpl: CLLocationManagerDelegate {
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.apply(status)
        }
    }
}
