//
//  MockDeviceLocationManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import DeviceLocationManager
import Foundation
import SwiftAsyncEx

@MainActor
public final class MockDeviceLocationManager: DeviceLocationManager {
    public let mutableAuthorization: MutableProperty<LocationAuthorization>
    public let mutableLocation: MutableProperty<Coordinate?>
    public var placeNames: [Coordinate: String] = [:]
    public var defaultPlaceName: String?
    public private(set) var authorizationRequests = 0

    public private(set) lazy var authorization: any PropertyProtocol<LocationAuthorization> = Property(mirroring: mutableAuthorization)
    public private(set) lazy var location: any PropertyProtocol<Coordinate?> = Property(mirroring: mutableLocation)

    public init(authorization: LocationAuthorization = .notDetermined, location: Coordinate? = nil) {
        self.mutableAuthorization = MutableProperty(authorization)
        self.mutableLocation = MutableProperty(location)
    }

    public func requestAuthorizationIfNeeded() {
        authorizationRequests += 1
    }

    public func placeName(for coordinate: Coordinate) async -> String? {
        placeNames[coordinate] ?? defaultPlaceName
    }
}
