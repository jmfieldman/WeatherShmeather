//
//  RootViewController.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import UIKit

/// The window's root for the life of the app. It holds the sign-in screen,
/// and the session coordinator presents the weather experience over it.
public protocol RootViewController: UIViewController, MainActorBuildable {
    /// Replaces the sign-in screen with a new one built from its Builder.
    ///
    /// The sign-in screen's model captures the managers of the container that
    /// was current when it was built. The coordinator calls this whenever the
    /// container is rebuilt for a signed-out session, so the screen always
    /// talks to the current managers.
    func installSignInScreen()
}

public struct RootViewControllerBuilder: Builder {
    public typealias BuildResult = RootViewController

    public init() {}
}
