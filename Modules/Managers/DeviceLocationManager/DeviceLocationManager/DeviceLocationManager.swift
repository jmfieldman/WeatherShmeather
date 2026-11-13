//
//  DeviceLocationManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SwiftAsyncEx

/// Whether the app may read the device's location.
public enum LocationAuthorization: Sendable, Equatable {
    /// The user hasn't been asked yet.
    case notDetermined
    /// The user said no, or the device doesn't allow it.
    case denied
    case authorized
}

/// A coordinate in degrees.
public struct Coordinate: Hashable, Sendable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in meters.
    public func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// CoreLocation's callbacks and streams, wrapped as reactive state.
///
/// Nothing here decides what a location means for the app; the places
/// manager does that. This manager only reports permission and position, and
/// names a coordinate on request.
@MainActor
public protocol DeviceLocationManager: AnyObject, Sendable {
    var authorization: Property<LocationAuthorization> { get }

    /// The latest position while authorized, or `nil`.
    var location: Property<Coordinate?> { get }

    /// Shows the system prompt if the user hasn't been asked. Otherwise does nothing.
    func requestAuthorizationIfNeeded()

    /// A short place name for `coordinate`, such as a city, from on-device
    /// reverse geocoding. `nil` if none could be found.
    func placeName(for coordinate: Coordinate) async -> String?
}
