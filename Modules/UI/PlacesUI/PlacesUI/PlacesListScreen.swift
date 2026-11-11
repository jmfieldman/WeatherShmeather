//
//  PlacesListScreen.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import UIKit

/// The list of the user's places: the base of the weather experience.
public protocol PlacesListScreen: UIViewController, MainActorBuildable {}

public struct PlacesListScreenBuilder: Builder {
    public typealias BuildResult = PlacesListScreen

    public init() {}
}
