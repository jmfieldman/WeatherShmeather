//
//  MockSessionManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SessionManager
import SwiftAsyncEx

@MainActor
public final class MockSessionManager: SessionManager {
    public let mutableCurrentUsername: MutableProperty<Username?>
    public let mutableRecentUsernames: MutableProperty<[Username]>
    public private(set) var signInCalls: [Username] = []
    public private(set) var logOutCount = 0

    public private(set) lazy var currentUsername: any PropertyProtocol<Username?> = Property(mirroring: mutableCurrentUsername)
    public private(set) lazy var recentUsernames: any PropertyProtocol<[Username]> = Property(mirroring: mutableRecentUsernames)

    public init(currentUsername: Username? = nil, recentUsernames: [Username] = []) {
        self.mutableCurrentUsername = MutableProperty(currentUsername)
        self.mutableRecentUsernames = MutableProperty(recentUsernames)
    }

    public func signIn(as username: Username) {
        signInCalls.append(username)
        mutableCurrentUsername.value = username
    }

    public func logOut() {
        logOutCount += 1
        mutableCurrentUsername.value = nil
    }
}
