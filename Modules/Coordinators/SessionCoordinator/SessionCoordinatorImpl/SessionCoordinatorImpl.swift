//
//  SessionCoordinatorImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import Foundation
import Inject
import Logging
import NetworkManager
import PlacesUI
import RootUI
import SessionCoordinator
import SessionManager
import SlateManager
import SwiftAsyncEx
import UIKit

@MainActor
public final class SessionCoordinatorImpl: SessionCoordinator {
    private let rootViewController: any RootViewController

    /// Observations of the current container's managers. Replaced whenever
    /// the container is, so nothing keeps watching a torn-down session.
    private var sessionBag = TaskBag()

    /// The presented weather experience, while a user is signed in.
    private weak var weatherExperience: UIViewController?

    private let mutableReadyForInjectionActivation = MutableProperty(false)
    public private(set) lazy var readyForInjectionActivation =
        Property(mirroring: mutableReadyForInjectionActivation)

    public required init(builder: SessionCoordinatorBuilder) {
        self.rootViewController = builder.rootViewController

        // Every launch starts signed out, with the sign-in screen at the root.
        installTransientContainer()
        rootViewController.installSignInScreen()

        // A user still signed in from last time goes straight in, with no
        // animation, so the sign-in screen never shows.
        if let username = Inject(SessionManager.self).currentUsername.value {
            startSession(as: username, animated: false)
        } else {
            observeSession()
        }
    }

    // MARK: Session transitions

    /// Watches the current container's `SessionManager` for a sign-in or a
    /// log out. Only transitions matter, so the initial value is skipped.
    ///
    /// The transition handlers run inside an observer bound to the bag they
    /// replace, so they must not suspend.
    private func observeSession() {
        let sessionManager: SessionManager = Inject()
        Task.observe(emitInitial: false, bindTo: sessionBag) { [sessionManager] in
            sessionManager.currentUsername.value
        } perform: { [weak self] username in
            if let username {
                self?.startSession(as: username, animated: true)
            } else {
                self?.endSession()
            }
        }
    }

    private func startSession(as username: Username, animated: Bool) {
        Log(.session, .info, "Starting session for \(username)")
        replaceContainer(userId: username.rawValue)
        mutableReadyForInjectionActivation.value = true

        let navigationController = UINavigationController(rootViewController: PlacesListScreenBuilder().build())
        navigationController.modalPresentationStyle = .fullScreen
        weatherExperience = navigationController
        rootViewController.present(navigationController, animated: animated)

        observeSession()
    }

    /// Dismisses the weather experience, and only then replaces the
    /// container: the screens on their way off screen still hold this
    /// session's managers, and must keep working until they're gone.
    private func endSession() {
        Log(.session, .info, "Ending session")
        sessionBag.cancelAll()
        mutableReadyForInjectionActivation.value = false

        let outgoing = OutgoingSession()
        let finish: @MainActor () -> Void = { [weak self] in
            guard let self else {
                return
            }

            replaceContainer(userId: nil)
            rootViewController.installSignInScreen()
            observeSession()
            outgoing.verifyReleased()
        }

        if let weatherExperience {
            weatherExperience.dismiss(animated: true) { finish() }
        } else {
            finish()
        }
    }

    // MARK: Container

    private func installTransientContainer() {
        InjectionManager.register(AppEnvironment.self) { AppEnvironment.transient }
    }

    /// Tears down every manager and registers the environment the next
    /// `Inject()` builds them against. This is the app's whole mechanism for
    /// per-user isolation.
    private func replaceContainer(userId: String?) {
        sessionBag.cancelAll()
        sessionBag = TaskBag()
        InjectionManager.resetCurrentContainer()

        if let userId {
            let environment = AppEnvironment(userId: userId)
            InjectionManager.register(AppEnvironment.self) { environment }
        } else {
            installTransientContainer()
        }
    }
}

/// Weak references to a session's managers, taken as it ends.
///
/// After the container is replaced, nothing should hold these managers. If
/// one survives, a screen or task from the old session is still alive and
/// could read or write the previous user's data. Debug builds check.
@MainActor
private struct OutgoingSession {
    private let managers: [(name: String, reference: WeakReference)]

    init() {
        self.managers = [
            ("AppEnvironment", WeakReference(Inject(AppEnvironment.self))),
            ("SessionManager", WeakReference(Inject(SessionManager.self))),
            ("SlateManager", WeakReference(Inject(SlateManager.self))),
            ("NetworkManager", WeakReference(Inject(NetworkManager.self))),
        ]
    }

    func verifyReleased() {
        #if DEBUG
        let managers = managers
        Task { @MainActor in
            // UIKit lets go of a dismissed hierarchy on its own schedule.
            try? await Task.sleep(for: .seconds(1))
            for (name, reference) in managers where reference.object != nil {
                Log(.session, .error, "\(name) from the previous session is still alive")
                assertionFailure("\(name) from the previous session is still alive")
            }
        }
        #endif
    }
}

private final class WeakReference {
    weak var object: AnyObject?

    init(_ object: AnyObject) {
        self.object = object
    }
}
