//
//  PlacesError.swift
//  Copyright © 2026 WeatherShmeather.
//

import Common
import Foundation
import PlacesManagerResources

public enum PlacesError: Error, Sendable, Equatable {
    /// Search couldn't reach Open-Meteo, or its answer couldn't be read.
    case searchFailed
    /// The local store refused a write.
    case storageFailed
    /// The result is already in the list.
    case alreadySaved
}

extension PlacesError: ErrorDialogProviding {
    public var errorTitle: String {
        .PlacesManager.placesErrorTitle
    }

    public var errorBody: String {
        switch self {
        case .searchFailed: .PlacesManager.placesErrorSearch
        case .storageFailed: .PlacesManager.placesErrorStorage
        case .alreadySaved: .PlacesManager.placesErrorAlreadySaved
        }
    }
}
