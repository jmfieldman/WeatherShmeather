//
//  SessionManagerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import Logging
import SessionManager
import SwiftAsyncEx

private let kMaxRecentUsernames = 5

@MainActor
public final class SessionManagerImpl: SessionManager {
    private let store: SessionStore

    public private(set) lazy var currentUsername: any PropertyProtocol<Username?> =
        Property(mirroring: store.currentUsername)

    public private(set) lazy var recentUsernames: any PropertyProtocol<[Username]> =
        Property(mirroring: store.recentUsernames)

    public init(store: SessionStore = .shared) {
        self.store = store
    }

    public func signIn(as username: Username) {
        Log(.session, .info, "Signing in as \(username)")
        store.recentUsernames.modify { recent in
            recent.removeAll { $0 == username }
            recent.insert(username, at: 0)
            recent = Array(recent.prefix(kMaxRecentUsernames))
        }
        store.currentUsername.value = username
    }

    public func logOut() {
        Log(.session, .info, "Logging out")
        store.currentUsername.value = nil
    }
}
