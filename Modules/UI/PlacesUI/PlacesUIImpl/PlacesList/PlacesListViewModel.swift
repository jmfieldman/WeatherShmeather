//
//  PlacesListViewModel.swift
//  Copyright © 2026 WeatherShmeather.
//

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

    public init(id: String, name: String, isCurrentLocation: Bool, timeZone: TimeZone?) {
        self.id = id
        self.name = name
        self.isCurrentLocation = isCurrentLocation
        self.timeZone = timeZone
    }

    public init(place: Place) {
        self.init(
            id: place.id,
            name: place.name,
            isCurrentLocation: place.isCurrentLocation,
            timeZone: place.isCurrentLocation ? nil : place.timeZone,
        )
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

    public init(
        cards: [PlaceCard] = [],
        hasLoaded: Bool = false,
        addTask: SerialTask<PlaceSearchResult, Void>,
        onDelete: @escaping @MainActor (String) -> Void = { _ in },
        onMove: @escaping @MainActor (IndexSet, Int) -> Void = { _, _ in },
        onSearchTextChange: @escaping @MainActor (String) -> Void = { _ in },
        onSelectCard: @escaping @MainActor (String) -> Void = { _ in },
    ) {
        self.cards = cards
        self.hasLoaded = hasLoaded
        self.addTask = addTask
        self.onDelete = onDelete
        self.onMove = onMove
        self.onSearchTextChange = onSearchTextChange
        self.onSelectCard = onSelectCard
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
