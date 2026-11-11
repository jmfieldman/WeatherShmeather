//
//  SceneDelegator.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import Inject
import Injection
import Logging
import RootUI
import SessionCoordinator
import SwiftAsyncEx
import UIKit

/// The real app bootstrap. `SceneDelegate` in the app target forwards here,
/// so this is the one place that knows about every top-level module.
@MainActor
public final class SceneDelegator {
    var window: UIWindow?
    var sessionCoordinator: (any SessionCoordinator)?

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

        let rootViewController = RootViewControllerBuilder().build()
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()

        // The coordinator installs the sign-in screen, and presents the
        // weather experience at once if a user is still signed in. The window
        // must already be visible for that presentation.
        let sessionCoordinator = SessionCoordinatorBuilder(rootViewController: rootViewController).build()
        self.sessionCoordinator = sessionCoordinator

        Task.observe(bindTo: self) { [sessionCoordinator] in
            sessionCoordinator.readyForInjectionActivation.value
        } perform: { isReady in
            if isReady {
                Log(.system, .info, "Activating injections")
                InjectionManager.activateInjections()
            }
        }

        Log(.system, .info, "scene:willConnectTo:options:")
    }
}
