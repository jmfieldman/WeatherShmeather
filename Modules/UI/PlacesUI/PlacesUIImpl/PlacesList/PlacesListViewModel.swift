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

/// A reorder in the card list, as SwiftUI reports it.
public struct CardMove: Hashable, Sendable {
    public let source: IndexSet
    public let destination: Int

    public init(source: IndexSet, destination: Int) {
        self.source = source
        self.destination = destination
    }
}

/// What the list view reads, and what it can ask for. State is read-only
/// `Property`s; every request is a `SerialTask` the screen model handles,
/// with the outcome flowing back through those properties.
@Observable @MainActor
public final class PlacesListViewModel {
    public let cards: Property<[PlaceCard]>
    /// The hero shows once the list is known to be empty, and never over search.
    public let showsEmptyState: Property<Bool>
    public let isEditing: Property<Bool>
    public let isSearching: Property<Bool>
    public let searchText: Property<String>
    public let searchState: Property<SearchState>
    /// Whether search leads with a Current Location row, which is offered
    /// while the app can't use the device's location.
    public let showsCurrentLocation: Property<Bool>
    /// A card to scroll into view once it appears, such as one just added.
    public let scrollTarget: Property<String?>

    public let selectCardTask: SerialTask<String, Void>
    public let refreshTask: SerialTask<Void, Void>
    public let deleteTask: SerialTask<IndexSet, Void>
    public let moveTask: SerialTask<CardMove, Void>
    public let beginSearchTask: SerialTask<Void, Void>
    public let endSearchTask: SerialTask<Void, Void>
    public let searchTextTask: SerialTask<String, Void>
    public let addTask: SerialTask<PlaceSearchResult, Void>
    public let currentLocationTask: SerialTask<Void, Void>
    public let scrolledToTargetTask: SerialTask<Void, Void>

    public init(
        cards: Property<[PlaceCard]> = .constant([]),
        showsEmptyState: Property<Bool> = .constant(false),
        isEditing: Property<Bool> = .constant(false),
        isSearching: Property<Bool> = .constant(false),
        searchText: Property<String> = .constant(""),
        searchState: Property<SearchState> = .constant(.idle),
        showsCurrentLocation: Property<Bool> = .constant(false),
        scrollTarget: Property<String?> = .constant(nil),
        selectCardTask: SerialTask<String, Void> = SerialTask { _ in },
        refreshTask: SerialTask<Void, Void> = SerialTask {},
        deleteTask: SerialTask<IndexSet, Void> = SerialTask { _ in },
        moveTask: SerialTask<CardMove, Void> = SerialTask { _ in },
        beginSearchTask: SerialTask<Void, Void> = SerialTask {},
        endSearchTask: SerialTask<Void, Void> = SerialTask {},
        searchTextTask: SerialTask<String, Void> = SerialTask { _ in },
        addTask: SerialTask<PlaceSearchResult, Void> = SerialTask { _ in },
        currentLocationTask: SerialTask<Void, Void> = SerialTask {},
        scrolledToTargetTask: SerialTask<Void, Void> = SerialTask {},
    ) {
        self.cards = cards
        self.showsEmptyState = showsEmptyState
        self.isEditing = isEditing
        self.isSearching = isSearching
        self.searchText = searchText
        self.searchState = searchState
        self.showsCurrentLocation = showsCurrentLocation
        self.scrollTarget = scrollTarget
        self.selectCardTask = selectCardTask
        self.refreshTask = refreshTask
        self.deleteTask = deleteTask
        self.moveTask = moveTask
        self.beginSearchTask = beginSearchTask
        self.endSearchTask = endSearchTask
        self.searchTextTask = searchTextTask
        self.addTask = addTask
        self.currentLocationTask = currentLocationTask
        self.scrolledToTargetTask = scrolledToTargetTask
    }
}
