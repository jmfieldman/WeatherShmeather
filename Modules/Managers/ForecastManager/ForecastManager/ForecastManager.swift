//
//  ForecastManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SwiftAsyncEx

/// Weather for every place in the user's list, cached in Slate.
///
/// The manager follows the places list on its own: a new place is fetched
/// at once, a removed place's weather is deleted, and the current location
/// is refetched when it moves. Screens only say when freshness matters.
@MainActor
public protocol ForecastManager: AnyObject, Sendable {
    /// The latest forecast for each place, by place id. Cached forecasts are
    /// here from launch, before any refresh.
    var forecasts: any PropertyProtocol<[String: Forecast]> { get }

    /// Places with a fetch in flight.
    var refreshingPlaceIds: any PropertyProtocol<Set<String>> { get }

    /// The last refresh failure for each place, cleared by its next success.
    var refreshErrors: any PropertyProtocol<[String: ForecastError]> { get }

    /// Fetches a place's weather if it's missing or older than 15 minutes.
    func refreshIfStale(placeId: String)

    /// Fetches every place whose weather is missing or older than 15 minutes.
    func refreshAllIfStale()

    /// Fetches every place now, whatever its age, and returns when all have
    /// finished. For pull to refresh.
    func refreshAll() async
}
