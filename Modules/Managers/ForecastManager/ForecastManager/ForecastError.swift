//
//  ForecastError.swift
//  Copyright © 2026 WeatherShmeather.
//

import Common
import ForecastManagerResources
import Foundation

public enum ForecastError: Error, Sendable, Equatable {
    /// The device couldn't reach Open-Meteo.
    case offline
    /// Open-Meteo answered with an error or something unreadable, or the
    /// result couldn't be saved.
    case failed
}

extension ForecastError: ErrorDialogProviding {
    public var errorTitle: String {
        .ForecastManager.forecastErrorTitle
    }

    public var errorBody: String {
        switch self {
        case .offline: .ForecastManager.forecastErrorOffline
        case .failed: .ForecastManager.forecastErrorFailed
        }
    }
}
