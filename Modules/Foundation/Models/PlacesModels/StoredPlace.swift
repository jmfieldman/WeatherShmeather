//
//  StoredPlace.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SlateSchema

/// One row of the user's places list.
///
/// At most one row has `isCurrentLocation == true`. The places manager owns
/// that row: it creates it when location permission is granted, overwrites it
/// as the device moves, and deletes it when permission is taken away. Every
/// other row is a place the user added from search.
@SlateEntity
public struct StoredPlace {
    #Unique<StoredPlace>([\.placeId])
    #Index<StoredPlace>([\.sortOrder])

    /// A UUID for a saved place, or a fixed id for the current location.
    public let placeId: String
    public let name: String
    /// State, province, or similar, when known.
    public let region: String?
    public let country: String?
    public let latitude: Double
    public let longitude: Double
    /// An IANA time zone identifier, such as `America/Los_Angeles`.
    public let timeZoneIdentifier: String?
    /// The user's order for saved places. The current location ignores it.
    public let sortOrder: Int64
    public let isCurrentLocation: Bool
    /// Open-Meteo's geocoding id, for saved places, so a result can't be saved twice.
    public let geocodingId: Int64?
}
