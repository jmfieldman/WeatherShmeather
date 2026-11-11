//
//  PlacesListScreenImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import Common
import Foundation
import Inject
import Logging
import PlacesManager
import PlacesUI
import PlacesUIResources
import SessionManager
import SFSafeSymbols
import SwiftAsyncEx
import SwiftUIEx
import UIKit

/// How long typing must pause before a search runs.
private let kSearchDebounce: Duration = .milliseconds(350)

@MainActor
public final class PlacesListScreenImpl: HostingScreen<PlacesListScreenModel, PlacesListView>, PlacesListScreen {
    public convenience init(builder: PlacesListScreenBuilder) {
        self.init(controllerModel: PlacesListScreenModel())
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        title = String.PlacesUI.placesTitle
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        let viewModel = controllerModel.viewModel
        Task.observe(bindTo: self) {
            viewModel.isEditing
        } perform: { [weak self] isEditing in
            self?.installBarButton(isEditing: isEditing)
        }

        // Search takes the whole screen, as its own mode.
        Task.observe(bindTo: self) {
            viewModel.isSearching
        } perform: { [weak self] isSearching in
            self?.navigationController?.setNavigationBarHidden(isSearching, animated: true)
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        controllerModel.screenDidAppear()
    }

    private func installBarButton(isEditing: Bool) {
        if isEditing {
            let done = UIBarButtonItem(
                image: UIImage(systemSymbol: .checkmark),
                primaryAction: UIAction { [weak controllerModel] _ in
                    controllerModel?.viewModel.isEditing = false
                },
            )
            done.style = .prominent
            done.accessibilityLabel = String.PlacesUI.placesDoneEditing
            navigationItem.rightBarButtonItem = done
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: String.PlacesUI.placesMoreMenu,
                image: UIImage(systemSymbol: .ellipsis),
                menu: makeMenu(),
            )
        }
    }

    /// Built each time it opens, so Edit List reflects the current list.
    private func makeMenu() -> UIMenu {
        UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak controllerModel] completion in
                guard let controllerModel else {
                    completion([])
                    return
                }

                completion(Self.menuElements(for: controllerModel))
            },
        ])
    }

    private static func menuElements(for model: PlacesListScreenModel) -> [UIMenuElement] {
        let edit = UIAction(
            title: String.PlacesUI.placesMenuEditList,
            image: UIImage(systemSymbol: .pencil),
            attributes: model.viewModel.canEdit ? [] : .disabled,
        ) { [weak model] _ in
            model?.viewModel.isEditing = true
        }

        let logOut = UIAction(
            title: String.PlacesUI.placesMenuLogOut,
            image: UIImage(systemSymbol: .rectanglePortraitAndArrowRight),
            attributes: .destructive,
        ) { [weak model] _ in
            model?.logOut()
        }

        return [
            UIMenu(options: .displayInline, children: [edit]),
            UIMenu(options: .displayInline, children: [logOut]),
        ]
    }
}

@MainActor
public final class PlacesListScreenModel: HostingScreenModel {
    public weak var viewController: UIViewController?
    public private(set) lazy var viewModel: PlacesListViewModel = .init(
        addTask: .weak(self) { `self`, result in
            await self.add(result)
        },
        onDelete: { [weak self] placeId in
            self?.delete(placeId: placeId)
        },
        onMove: { [weak self] source, destination in
            self?.move(fromOffsets: source, toOffset: destination)
        },
        onSearchTextChange: { [weak self] text in
            self?.searchTextChanged(text)
        },
    )

    private let placesManager: PlacesManager = Inject()
    private let sessionManager: SessionManager = Inject()

    /// The pending or running search; replaced on every keystroke.
    private var searchBag = TaskBag()
    private var latestResults: [PlaceSearchResult] = []

    public init() {
        Task.observe(bindTo: self) { [placesManager] in
            placesManager.places.value
        } perform: { [weak self] places in
            self?.viewModel.cards = places.map(PlaceCard.init(place:))
            if self?.viewModel.canEdit == false {
                self?.viewModel.isEditing = false
            }
        }

        Task.observe(bindTo: self) { [placesManager] in
            placesManager.hasLoaded.value
        } perform: { [weak self] hasLoaded in
            self?.viewModel.hasLoaded = hasLoaded
        }

        // A place added elsewhere, or this one, marks its result as saved.
        Task.observe(bindTo: self) { [placesManager] in
            placesManager.savedGeocodingIds.value
        } perform: { [weak self] _ in
            self?.publishResults()
        }
    }

    func screenDidAppear() {
        placesManager.requestLocationAuthorizationIfNeeded()
    }

    func logOut() {
        sessionManager.logOut()
    }

    // MARK: Search

    private func searchTextChanged(_ text: String) {
        searchBag.cancelAll()
        searchBag = TaskBag()

        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            latestResults = []
            viewModel.searchState = .idle
            return
        }

        viewModel.searchState = .loading
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: kSearchDebounce)
            guard !Task.isCancelled else {
                return
            }

            await self?.runSearch(query)
        }
        .bind(to: searchBag)
    }

    private func runSearch(_ query: String) async {
        do {
            let results = try await placesManager.search(query)
            guard !Task.isCancelled else {
                return
            }

            latestResults = results
            viewModel.searchState = results.isEmpty ? .noResults(query: query) : .loading
            publishResults()
        } catch {
            guard !Task.isCancelled else {
                return
            }

            latestResults = []
            viewModel.searchState = .failed(message: error.errorBody)
        }
    }

    private func publishResults() {
        guard !latestResults.isEmpty else {
            return
        }

        let saved = placesManager.savedGeocodingIds.value
        viewModel.searchState = .results(latestResults.map { SearchRow(result: $0, isSaved: saved.contains($0.id)) })
    }

    // MARK: Editing

    private func add(_ result: PlaceSearchResult) async {
        do {
            let place = try await placesManager.add(result)
            latestResults = []
            viewModel.endSearch()
            viewModel.scrollTarget = place.id
        } catch {
            viewController?.present(error: error)
        }
    }

    private func delete(placeId: String) {
        Task { @MainActor [weak self, placesManager] in
            do throws(PlacesError) {
                try await placesManager.delete(placeId: placeId)
            } catch {
                self?.viewController?.present(error: error)
            }
        }
        .bind(to: self)
    }

    private func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        Task { @MainActor [weak self, placesManager] in
            do throws(PlacesError) {
                try await placesManager.moveSavedPlaces(fromOffsets: source, toOffset: destination)
            } catch {
                self?.viewController?.present(error: error)
            }
        }
        .bind(to: self)
    }
}
