//
//  Place.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// A place in the user's list: a saved place, or the current location.
public struct Place: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let region: String?
    public let country: String?
    public let latitude: Double
    public let longitude: Double
    public let timeZone: TimeZone?
    public let isCurrentLocation: Bool

    public init(
        id: String,
        name: String,
        region: String?,
        country: String?,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone?,
        isCurrentLocation: Bool,
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
        self.isCurrentLocation = isCurrentLocation
    }
}

/// A place found by search, not yet saved.
public struct PlaceSearchResult: Hashable, Sendable, Identifiable {
    /// Open-Meteo's geocoding id.
    public let id: Int64
    public let name: String
    public let region: String?
    public let country: String?
    public let latitude: Double
    public let longitude: Double
    public let timeZone: TimeZone?

    public init(
        id: Int64,
        name: String,
        region: String?,
        country: String?,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone?,
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
    }

    /// Region and country, for a secondary line such as "California, United States".
    public var detail: String {
        [region, country].compactMap(\.self).filter { !$0.isEmpty && $0 != name }.joined(separator: ", ")
    }
}
