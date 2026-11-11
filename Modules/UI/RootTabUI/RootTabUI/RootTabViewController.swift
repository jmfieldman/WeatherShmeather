//
//  RootTabViewController.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import UIKit

public protocol RootTabViewController: UIViewController, MainActorBuildable {
    /// Called by the session coordinator whenever a user session starts. It
    /// rebuilds every tab from its Builder, so the new screens capture the
    /// new session's managers.
    func installNewViewControllers()
}

public struct RootTabViewControllerBuilder: Builder {
    public typealias BuildResult = RootTabViewController

    public init() {}
}
