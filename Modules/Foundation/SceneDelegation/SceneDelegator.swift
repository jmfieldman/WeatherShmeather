//
//  SceneDelegator.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import Foundation
import Inject
import Injection
import Logging
import RootTabUI
import UIKit

/// The real app bootstrap. `SceneDelegate` in the app target forwards here,
/// so this is the one place that knows about every top-level module.
@MainActor
public final class SceneDelegator {
    var window: UIWindow?
    var rootTabViewController: (any RootTabViewController)?

    public init() {}

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }

        #if DEBUG
        InjectionManager.detectResolutionCycles = true
        #endif
        InjectionManager.registerInjections()
        BuilderManager.registerBuilders()
        Logger.start()

        // Until the session coordinator exists, run in the transient
        // environment: no user is signed in.
        InjectionManager.register(AppEnvironment.self) { AppEnvironment.transient }

        let rootTabViewController = RootTabViewControllerBuilder().build()
        self.rootTabViewController = rootTabViewController

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = rootTabViewController
        window?.makeKeyAndVisible()

        rootTabViewController.installNewViewControllers()
        InjectionManager.activateInjections()

        Log(.system, .info, "scene:willConnectTo:options:")
    }
}
