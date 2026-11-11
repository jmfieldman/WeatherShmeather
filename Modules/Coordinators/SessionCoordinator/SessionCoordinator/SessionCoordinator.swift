//
//  SessionCoordinator.swift
//  Copyright © 2026 WeatherShmeather.
//

import Inject
import RootUI
import SwiftAsyncEx
import UIKit

/// Owns the user-session lifecycle: restoring the signed-in user at launch,
/// rebuilding the injection container on sign-in and log out, and
/// presenting or dismissing the weather experience over the root.
public protocol SessionCoordinator: MainActorBuildable {
    /// True while a user's managers are installed. The `SceneDelegator`
    /// activates injections on each false-to-true edge.
    var readyForInjectionActivation: any PropertyProtocol<Bool> { get }
}

public struct SessionCoordinatorBuilder: Builder {
    public typealias BuildResult = SessionCoordinator

    public let rootViewController: any RootViewController

    public init(rootViewController: any RootViewController) {
        self.rootViewController = rootViewController
    }
}
