//
//  PlaceForecastScreen.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import UIKit

/// One place's weather in full: a page of the place pager.
public protocol PlaceForecastScreen: UIViewController, MainActorBuildable {
    var placeId: String { get }
}

public struct PlaceForecastScreenBuilder: Builder {
    public typealias BuildResult = PlaceForecastScreen

    public let placeId: String

    public init(placeId: String) {
        self.placeId = placeId
    }
}
