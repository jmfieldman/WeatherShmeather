//
//  SignInScreen.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import UIKit

/// The username sign-in. It always sits at the root of the window, beneath
/// the weather experience.
public protocol SignInScreen: UIViewController, MainActorBuildable {}

public struct SignInScreenBuilder: Builder {
    public typealias BuildResult = SignInScreen

    public init() {}
}
