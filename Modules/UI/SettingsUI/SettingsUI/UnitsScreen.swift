//
//  UnitsScreen.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import UIKit

/// The Units sheet: temperature, other units, and display settings.
public protocol UnitsScreen: UIViewController, MainActorBuildable {}

public struct UnitsScreenBuilder: Builder {
    public typealias BuildResult = UnitsScreen

    public init() {}
}
