//
//  PlacePagerScreen.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import UIKit

/// Full-screen pages, one per place in list order, swiped horizontally,
/// with a page indicator and a button back to the list.
public protocol PlacePagerScreen: UIViewController, MainActorBuildable {}

public struct PlacePagerScreenBuilder: Builder {
    public typealias BuildResult = PlacePagerScreen

    /// The page to open on, or `nil` for the first.
    public let initialPlaceId: String?

    public init(initialPlaceId: String?) {
        self.initialPlaceId = initialPlaceId
    }
}
