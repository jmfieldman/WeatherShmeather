//
//  PlacesListScreenImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import Common
import ForecastManager
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
        onRefresh: { [weak self] in
            await self?.forecastManager.refreshAll()
        },
    )

    private let placesManager: PlacesManager = Inject()
    private let sessionManager: SessionManager = Inject()
    private let preferencesManager: PreferencesManager = Inject()
    private let forecastManager: ForecastManager = Inject()

    /// The pending or running search; replaced on every keystroke.
    private var searchBag = TaskBag()
    private var latestResults: [PlaceSearchResult] = []

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
            viewModel.cards = places.map { place in
                PlaceCard(place: place, weather: forecasts[place.id].map { Self.cardWeather($0, formatter: formatter) })
            }
            if !viewModel.canEdit {
                viewModel.isEditing = false
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
