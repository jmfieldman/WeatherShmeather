//
//  SceneDelegate.swift
//  Copyright © 2026 WeatherShmeather.
//

import SceneDelegation
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    /// All app bootstrap lives in `SceneDelegator`, inside the modules
    /// hierarchy, so this file stays a thin forwarder.
    let sceneDelegator = SceneDelegator()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        sceneDelegator.scene(scene, willConnectTo: session, options: connectionOptions)
    }
}
