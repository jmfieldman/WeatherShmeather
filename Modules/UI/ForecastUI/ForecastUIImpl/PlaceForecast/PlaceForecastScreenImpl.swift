//
//  PlaceForecastScreenImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import ForecastManager
import ForecastUI
import Foundation
import Inject
import PlacesManager
import PreferencesManager
import SwiftAsyncEx
import SwiftUIEx
import UIKit

@MainActor
public final class PlaceForecastScreenImpl: HostingScreen<PlaceForecastScreenModel, PlaceForecastView>, PlaceForecastScreen {
    public var placeId: String {
        controllerModel.placeId
    }

    public convenience init(builder: PlaceForecastScreenBuilder) {
        self.init(controllerModel: PlaceForecastScreenModel(placeId: builder.placeId))
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        // The page draws its own full-bleed background.
        view.backgroundColor = .clear
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controllerModel.screenWillAppear()
    }
}

@MainActor
public final class PlaceForecastScreenModel: HostingScreenModel {
    public weak var viewController: UIViewController?
    public private(set) lazy var viewModel = PlaceForecastViewModel(
        state: Property(mirroring: state),
        metric: Property(mirroring: metric),
        metricTask: .weak(self) { `self`, metric in
            self.metric.value = metric
        },
        retryTask: .weak(self) { `self` in
            // With no forecast on hand, a stale check always fetches.
            self.forecastManager.refreshIfStale(placeId: self.placeId)
        },
    )

    let placeId: String
    private let state = MutableProperty<PlaceForecastViewModel.State>(.loading(name: ""))
    private let metric = MutableProperty<PlaceForecastViewModel.Metric>(.temperature)
    private let placesManager: PlacesManager = Inject()
    private let forecastManager: ForecastManager = Inject()
    private let preferencesManager: PreferencesManager = Inject()

    public init(placeId: String) {
        self.placeId = placeId

        // The page is a function of four sources; any change rebuilds it.
        Task.observe(bindTo: self) { [placesManager, forecastManager, preferencesManager, placeId] in
            (
                placesManager.places.value.first { $0.id == placeId },
                forecastManager.forecasts.value[placeId],
                forecastManager.refreshErrors.value[placeId],
                preferencesManager.unitSettings.value,
            )
        } perform: { [weak self] place, forecast, error, settings in
            self?.update(place: place, forecast: forecast, error: error, settings: settings)
        }
    }

    func screenWillAppear() {
        forecastManager.refreshIfStale(placeId: placeId)
    }

    private func update(place: Place?, forecast: Forecast?, error: ForecastError?, settings: UnitSettings) {
        guard let place else {
            return
        }

        if let forecast {
            state.value = .loaded(PlaceForecastContent.make(place: place, forecast: forecast, settings: settings, now: Date()))
        } else if let error {
            state.value = .failed(name: place.name, message: error.errorBody)
        } else {
            state.value = .loading(name: place.name)
        }
    }
}
