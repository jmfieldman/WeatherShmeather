//
//  SessionStore.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import Foundation
import SessionManager
import SwiftAsyncEx

/// The persistent properties behind `SessionManager`.
///
/// Every session builds its own `SessionManagerImpl`, but these values must
/// outlive every session, so they live in one process-wide store instead of
/// on the manager. Two managers with their own `PersistentProperty` for the
/// same key would each hold a separate in-memory copy, and a write through
/// one would never reach observers of the other.
@MainActor
public final class SessionStore {
    /// The app's store, on the transient environment's property files.
    public static let shared = SessionStore(storageEngine: AppEnvironment.transient.propertyFileStore)

    let currentUsername: PersistentProperty<Username?>
    let recentUsernames: PersistentProperty<[Username]>

    public init(storageEngine: PersistentPropertyStorageEngine) {
        self.currentUsername = .init(storageEngine: storageEngine, key: "SessionCurrentUsername", defaultValue: nil)
        self.recentUsernames = .init(storageEngine: storageEngine, key: "SessionRecentUsernames", defaultValue: [])
    }
}
