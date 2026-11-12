//
//  PlacesListScreenImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import Common
import DeviceLocationManager
import ForecastManager
import ForecastUI
import Foundation
import Inject
import Logging
import PlacesManager
import PlacesUI
import PlacesUIResources
import PreferencesManager
import SessionManager
import SettingsUI
import SFSafeSymbols
import SwiftAsyncEx
import SwiftUIEx
import UIKit
import WeatherDisplay

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
            viewModel.isEditing.value
        } perform: { [weak self] isEditing in
            self?.installBarButton(isEditing: isEditing)
        }

        // Search takes the whole screen, as its own mode.
        Task.observe(bindTo: self) {
            viewModel.isSearching.value
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
                    controllerModel?.setEditing(false)
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
            attributes: model.canEdit ? [] : .disabled,
        ) { [weak model] _ in
            model?.setEditing(true)
        }

        let logOut = UIAction(
            title: String.PlacesUI.placesMenuLogOut,
            image: UIImage(systemSymbol: .rectanglePortraitAndArrowRight),
            attributes: .destructive,
        ) { [weak model] _ in
            model?.logOut()
        }

        // A quick switch for the one setting people change most. It writes
        // the same preference as the Units sheet.
        let temperature = model.resolvedTemperatureUnit
        let celsius = UIAction(
            title: String.PlacesUI.placesMenuCelsius,
            image: UIImage(systemSymbol: .degreesignCelsius),
            state: temperature == .celsius ? .on : .off,
        ) { [weak model] _ in
            model?.setTemperatureUnit(.celsius)
        }
        let fahrenheit = UIAction(
            title: String.PlacesUI.placesMenuFahrenheit,
            image: UIImage(systemSymbol: .degreesignFahrenheit),
            state: temperature == .fahrenheit ? .on : .off,
        ) { [weak model] _ in
            model?.setTemperatureUnit(.fahrenheit)
        }

        let units = UIAction(
            title: String.PlacesUI.placesMenuUnits,
            image: UIImage(systemSymbol: .chartBarXaxis),
        ) { [weak model] _ in
            model?.presentUnits()
        }

        return [
            UIMenu(options: .displayInline, children: [edit]),
            UIMenu(options: .displayInline, children: [celsius, fahrenheit]),
            UIMenu(options: .displayInline, children: [units]),
            UIMenu(options: .displayInline, children: [logOut]),
        ]
    }
}

@MainActor
public final class PlacesListScreenModel: HostingScreenModel {
    public weak var viewController: UIViewController?
    public private(set) lazy var viewModel = PlacesListViewModel(
        cards: Property(mirroring: cards),
        showsEmptyState: Property(tracking: { [hasLoaded, cards, isSearching] in
            hasLoaded.value && cards.value.isEmpty && !isSearching.value
        }),
        isEditing: Property(mirroring: isEditing),
        isSearching: Property(mirroring: isSearching),
        searchText: Property(mirroring: searchText),
        searchState: Property(mirroring: searchState),
        showsCurrentLocation: Property(tracking: { [placesManager] in
            placesManager.locationAuthorization.value != .authorized
        }),
        scrollTarget: Property(mirroring: scrollTarget),
        selectCardTask: .weak(self) { `self`, placeId in
            self.openPager(at: placeId, animated: true)
        },
        refreshTask: .weak(self) { `self` in
            await self.forecastManager.refreshAll()
        },
        deleteTask: .weak(self) { `self`, offsets in
            self.deleteCards(atOffsets: offsets)
        },
        moveTask: .weak(self) { `self`, move in
            self.moveCards(move)
        },
        beginSearchTask: .weak(self) { `self` in
            self.beginSearch()
        },
        endSearchTask: .weak(self) { `self` in
            self.endSearch()
        },
        searchTextTask: .weak(self) { `self`, text in
            self.searchTextChanged(text)
        },
        addTask: .weak(self) { `self`, result in
            await self.add(result)
        },
        currentLocationTask: .weak(self) { `self` in
            self.useCurrentLocation()
        },
        scrolledToTargetTask: .weak(self) { `self` in
            self.scrollTarget.value = nil
        },
    )

    // The screen's state. The view model mirrors these read-only.
    private let cards = MutableProperty<[PlaceCard]>([])
    private let hasLoaded = MutableProperty(false)
    private let isEditing = MutableProperty(false)
    private let isSearching = MutableProperty(false)
    private let searchText = MutableProperty("")
    private let searchState = MutableProperty<SearchState>(.idle)
    private let scrollTarget = MutableProperty<String?>(nil)

    private let placesManager: PlacesManager = Inject()
    private let sessionManager: SessionManager = Inject()
    private let preferencesManager: PreferencesManager = Inject()
    private let forecastManager: ForecastManager = Inject()

    /// The pending or running search; replaced on every keystroke.
    private var searchBag = TaskBag()
    private var latestResults: [PlaceSearchResult] = []

    /// The pager opens by itself once, when the list first loads.
    private var hasOpenedInitialPage = false

    /// Set while the system permission prompt from the Current Location row
    /// is up, so the answer can close search.
    private var isAwaitingAuthorization = false
    /// Set once permission is granted from search, until the current
    /// location's card exists to scroll to.
    private var scrollsToCurrentLocation = false

    public init() {
        // Cards combine three sources: the places, their forecasts, and the
        // units to show them in. A change to any one rebuilds the cards.
        Task.observe(bindTo: self) { [placesManager, forecastManager, preferencesManager] in
            (placesManager.places.value, forecastManager.forecasts.value, preferencesManager.unitSettings.value)
        } perform: { [weak self] places, forecasts, settings in
            guard let self else {
                return
            }

            let formatter = WeatherFormatter(settings: settings)
            cards.value = places.map { place in
                PlaceCard(place: place, weather: forecasts[place.id].map { Self.cardWeather($0, formatter: formatter) })
            }
            if !canEdit {
                isEditing.value = false
            }
            scrollToCurrentLocationIfReady()
        }

        Task.observe(bindTo: self) { [placesManager] in
            placesManager.locationAuthorization.value
        } perform: { [weak self] authorization in
            self?.authorizationChanged(authorization)
        }

        Task.observe(bindTo: self) { [placesManager] in
            placesManager.hasLoaded.value
        } perform: { [weak self] hasLoaded in
            self?.hasLoaded.value = hasLoaded
            self?.openInitialPageIfNeeded()
        }

        // A place added elsewhere, or this one, marks its result as saved.
        Task.observe(bindTo: self) { [placesManager] in
            placesManager.savedGeocodingIds.value
        } perform: { [weak self] _ in
            self?.publishResults()
        }
    }

    func screenDidAppear() {
        // Location permission isn't asked for here: the user opts in from
        // the Current Location row in search.
        forecastManager.refreshAllIfStale()
    }

    static func cardWeather(_ forecast: Forecast, formatter: WeatherFormatter) -> CardWeather {
        let current = forecast.current
        let highLow = forecast.today.map {
            String.highLow(high: formatter.temperature(celsius: $0.high), low: formatter.temperature(celsius: $0.low))
        } ?? ""
        return CardWeather(
            temperature: formatter.temperature(celsius: current.temperature),
            condition: current.weatherCode.name(isDay: current.isDay),
            highLow: highLow,
            weatherCode: current.weatherCode,
            isDay: current.isDay,
            timeZone: forecast.timeZone,
            updatedAt: forecast.fetchedAt,
        )
    }

    /// At launch and sign-in the weather experience opens on a place, not
    /// the list: the current location if there is one, else the first saved
    /// place. With no places, it stays on the list's empty state.
    private func openInitialPageIfNeeded() {
        guard !hasOpenedInitialPage, placesManager.hasLoaded.value else {
            return
        }

        hasOpenedInitialPage = true
        if let first = placesManager.places.value.first {
            openPager(at: first.id, animated: false)
        }
    }

    private func openPager(at placeId: String, animated: Bool) {
        guard !isEditing.value, !isSearching.value else {
            return
        }

        let pager = PlacePagerScreenBuilder(initialPlaceId: placeId).build()
        viewController?.navigationController?.pushViewController(pager, animated: animated)
    }

    // MARK: Menu

    /// Whether there is anything Edit List could change.
    var canEdit: Bool {
        cards.value.contains { !$0.isCurrentLocation }
    }

    func setEditing(_ editing: Bool) {
        isEditing.value = editing && canEdit
    }

    func logOut() {
        sessionManager.logOut()
    }

    var resolvedTemperatureUnit: TemperatureUnit {
        preferencesManager.resolvedTemperatureUnit.value
    }

    func setTemperatureUnit(_ unit: TemperatureUnitPreference) {
        preferencesManager.setTemperatureUnit(unit)
    }

    func presentUnits() {
        let navigationController = UINavigationController(rootViewController: UnitsScreenBuilder().build())
        navigationController.modalPresentationStyle = .pageSheet
        viewController?.present(navigationController, animated: true)
    }

    // MARK: Search

    private func beginSearch() {
        isEditing.value = false
        isSearching.value = true
    }

    private func endSearch() {
        searchBag.cancelAll()
        latestResults = []
        isSearching.value = false
        searchText.value = ""
        searchState.value = .idle
    }

    private func searchTextChanged(_ text: String) {
        guard text != searchText.value else {
            return
        }

        searchText.value = text
        searchBag.cancelAll()
        searchBag = TaskBag()

        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            latestResults = []
            searchState.value = .idle
            return
        }

        searchState.value = .loading
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
            searchState.value = results.isEmpty ? .noResults(query: query) : .loading
            publishResults()
        } catch {
            guard !Task.isCancelled else {
                return
            }

            latestResults = []
            searchState.value = .failed(message: error.errorBody)
        }
    }

    private func publishResults() {
        guard !latestResults.isEmpty else {
            return
        }

        let saved = placesManager.savedGeocodingIds.value
        searchState.value = .results(latestResults.map { SearchRow(result: $0, isSaved: saved.contains($0.id)) })
    }

    // MARK: Current location

    /// The Current Location row asks for permission the first time. Once
    /// the user has said no, only Settings can change that, so it offers to
    /// open them.
    private func useCurrentLocation() {
        switch placesManager.locationAuthorization.value {
        case .notDetermined:
            isAwaitingAuthorization = true
            placesManager.requestLocationAuthorizationIfNeeded()

        case .denied:
            presentLocationSettingsAlert()

        case .authorized:
            endSearch()
        }
    }

    /// Granting permission from search closes it, and the list scrolls to
    /// the current location once its card arrives. Declining leaves search open.
    private func authorizationChanged(_ authorization: LocationAuthorization) {
        guard isAwaitingAuthorization, authorization != .notDetermined else {
            return
        }

        isAwaitingAuthorization = false
        if authorization == .authorized {
            endSearch()
            scrollsToCurrentLocation = true
            scrollToCurrentLocationIfReady()
        }
    }

    private func scrollToCurrentLocationIfReady() {
        guard scrollsToCurrentLocation, let first = cards.value.first, first.isCurrentLocation else {
            return
        }

        scrollsToCurrentLocation = false
        scrollTarget.value = first.id
    }

    private func presentLocationSettingsAlert() {
        let alert = UIAlertController(
            title: String.PlacesUI.placesLocationAlertTitle,
            message: String.PlacesUI.placesLocationAlertBody,
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(title: String.PlacesUI.placesLocationAlertCancel, style: .cancel))
        let settings = UIAlertAction(title: String.PlacesUI.placesLocationAlertSettings, style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        alert.addAction(settings)
        alert.preferredAction = settings
        viewController?.present(alert, animated: true)
    }

    // MARK: Editing

    private func add(_ result: PlaceSearchResult) async {
        do {
            let place = try await placesManager.add(result)
            endSearch()
            scrollTarget.value = place.id
        } catch {
            viewController?.present(error: error)
        }
    }

    /// The fixed current-location card leads the list but isn't a saved
    /// place, so offsets into the cards are shifted past it.
    private var currentLocationCount: Int {
        cards.value.prefix { $0.isCurrentLocation }.count
    }

    /// Deletes every saved place at the offsets. Each delete runs on its own,
    /// so this returns as soon as they are started.
    private func deleteCards(atOffsets offsets: IndexSet) {
        let placeIds = offsets.compactMap { index in
            cards.value.indices.contains(index) && !cards.value[index].isCurrentLocation ? cards.value[index].id : nil
        }
        for placeId in placeIds {
            Task { @MainActor [weak self, placesManager] in
                do throws(PlacesError) {
                    try await placesManager.delete(placeId: placeId)
                } catch {
                    self?.viewController?.present(error: error)
                }
            }
            .bind(to: self)
        }
    }

    /// Converts a move in the full card list into a move among saved places.
    private func moveCards(_ move: CardMove) {
        let offset = currentLocationCount
        let source = IndexSet(move.source.compactMap { $0 >= offset ? $0 - offset : nil })
        guard !source.isEmpty else {
            return
        }

        let destination = max(move.destination - offset, 0)
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
