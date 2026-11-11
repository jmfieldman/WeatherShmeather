//
//  SessionManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SwiftAsyncEx

/// Who is signed in, and who signed in recently.
///
/// Signing in and logging out only change `currentUsername`. The session
/// coordinator observes it and does the real work: rebuilding the injection
/// container around the new user's environment and presenting or dismissing
/// the weather experience.
@MainActor
public protocol SessionManager: AnyObject, Sendable {
    /// The signed-in user, or `nil` when no one is.
    var currentUsername: any PropertyProtocol<Username?> { get }

    /// The last five usernames that signed in on this device, most recent first.
    var recentUsernames: any PropertyProtocol<[Username]> { get }

    func signIn(as username: Username)

    func logOut()
}
