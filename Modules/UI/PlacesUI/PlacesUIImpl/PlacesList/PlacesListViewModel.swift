//
//  PlacesListViewModel.swift
//  Copyright © 2026 WeatherShmeather.
//

import ForecastManager
import Foundation
import PlacesManager
import SwiftAsyncEx

/// One card in the list.
public struct PlaceCard: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let isCurrentLocation: Bool
    /// The place's time zone, for its local time. `nil` for the current
    /// location, which shows "My Location" instead.
    public let timeZone: TimeZone?
    /// `nil` until the place's first forecast arrives.
    public let weather: CardWeather?

    public init(id: String, name: String, isCurrentLocation: Bool, timeZone: TimeZone?, weather: CardWeather? = nil) {
        self.id = id
        self.name = name
        self.isCurrentLocation = isCurrentLocation
        self.timeZone = timeZone
        self.weather = weather
    }

    public init(place: Place, weather: CardWeather?) {
        self.init(
            id: place.id,
            name: place.name,
            isCurrentLocation: place.isCurrentLocation,
            timeZone: place.isCurrentLocation ? nil : (weather?.timeZone ?? place.timeZone),
            weather: weather,
        )
    }
}

/// A card's weather, already formatted in the user's units.
public struct CardWeather: Hashable, Sendable {
    public let temperature: String
    public let condition: String
    public let highLow: String
    public let weatherCode: WeatherCode
    public let isDay: Bool
    public let timeZone: TimeZone
    /// When the weather was fetched, so an old card can say so.
    public let updatedAt: Date

    public init(
        temperature: String,
        condition: String,
        highLow: String,
        weatherCode: WeatherCode,
        isDay: Bool,
        timeZone: TimeZone,
        updatedAt: Date,
    ) {
        self.temperature = temperature
        self.condition = condition
        self.highLow = highLow
        self.weatherCode = weatherCode
        self.isDay = isDay
        self.timeZone = timeZone
        self.updatedAt = updatedAt
    }
}

/// One search result row.
public struct SearchRow: Hashable, Sendable, Identifiable {
    public let result: PlaceSearchResult
    public let isSaved: Bool

    public var id: Int64 {
        result.id
    }

    public init(result: PlaceSearchResult, isSaved: Bool) {
        self.result = result
        self.isSaved = isSaved
    }
}

public enum SearchState: Equatable, Sendable {
    /// Nothing typed yet.
    case idle
    case loading
    case results([SearchRow])
    case noResults(query: String)
    case failed(message: String)
}

@Observable @MainActor
public final class PlacesListViewModel {
    public var cards: [PlaceCard]
    public var hasLoaded: Bool
    public var isEditing = false

    public var isSearching = false
    public var searchText = "" {
        didSet {
            if searchText != oldValue {
                onSearchTextChange(searchText)
            }
        }
    }

    public var searchState: SearchState = .idle

    /// A card to scroll into view once it appears, such as one just added.
    public var scrollTarget: String?

    public let addTask: SerialTask<PlaceSearchResult, Void>
    /// Deletes and moves are fire-and-forget: each one must run, so they
    /// aren't `SerialTask`s, which drop a call made while one is running.
    @ObservationIgnored let onDelete: @MainActor (String) -> Void
    @ObservationIgnored let onMove: @MainActor (IndexSet, Int) -> Void
    @ObservationIgnored let onSearchTextChange: @MainActor (String) -> Void
    @ObservationIgnored let onSelectCard: @MainActor (String) -> Void
    @ObservationIgnored let onRefresh: @MainActor () async -> Void

    public init(
        cards: [PlaceCard] = [],
        hasLoaded: Bool = false,
        addTask: SerialTask<PlaceSearchResult, Void>,
        onDelete: @escaping @MainActor (String) -> Void = { _ in },
        onMove: @escaping @MainActor (IndexSet, Int) -> Void = { _, _ in },
        onSearchTextChange: @escaping @MainActor (String) -> Void = { _ in },
        onSelectCard: @escaping @MainActor (String) -> Void = { _ in },
        onRefresh: @escaping @MainActor () async -> Void = {},
    ) {
        self.cards = cards
        self.hasLoaded = hasLoaded
        self.addTask = addTask
        self.onDelete = onDelete
        self.onMove = onMove
        self.onSearchTextChange = onSearchTextChange
        self.onSelectCard = onSelectCard
        self.onRefresh = onRefresh
    }

    /// The hero shows once the list is known to be empty, and never over search.
    public var showsEmptyState: Bool {
        hasLoaded && cards.isEmpty && !isSearching
    }

    /// Whether there is anything Edit List could change.
    public var canEdit: Bool {
        cards.contains { !$0.isCurrentLocation }
    }

    private var currentLocationCount: Int {
        cards.prefix { $0.isCurrentLocation }.count
    }

    public func beginSearch() {
        isEditing = false
        isSearching = true
    }

    public func endSearch() {
        isSearching = false
        searchText = ""
        searchState = .idle
    }

    /// Converts a move in the full card list, which may include the fixed
    /// current-location card, into a move among saved places only.
    public func moveCards(fromOffsets source: IndexSet, toOffset destination: Int) {
        let offset = currentLocationCount
        let savedSource = IndexSet(source.compactMap { $0 >= offset ? $0 - offset : nil })
        guard !savedSource.isEmpty else {
            return
        }

        onMove(savedSource, max(destination - offset, 0))
    }

    public func deleteCards(atOffsets offsets: IndexSet) {
        for index in offsets where !cards[index].isCurrentLocation {
            onDelete(cards[index].id)
        }
    }
}
