//
//  SessionManagerImplTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import SessionManager
import SessionManagerImpl
import SwiftAsyncEx
import Testing

@MainActor
struct SessionManagerImplTests {
    private func name(_ text: String) -> Username {
        Username(text)!
    }

    @Test func signInSetsTheCurrentUserAndRecents() {
        let manager = SessionManagerImpl(store: SessionStore(storageEngine: InMemoryStorageEngine()))

        manager.signIn(as: name("alice"))

        #expect(manager.currentUsername.value == name("alice"))
        #expect(manager.recentUsernames.value == [name("alice")])
    }

    @Test func recentsAreMostRecentFirstWithoutDuplicates() {
        let manager = SessionManagerImpl(store: SessionStore(storageEngine: InMemoryStorageEngine()))

        manager.signIn(as: name("alice"))
        manager.signIn(as: name("bob"))
        manager.signIn(as: name("alice"))

        #expect(manager.recentUsernames.value == [name("alice"), name("bob")])
    }

    @Test func recentsKeepFive() {
        let manager = SessionManagerImpl(store: SessionStore(storageEngine: InMemoryStorageEngine()))

        for text in ["a", "b", "c", "d", "e", "f"] {
            manager.signIn(as: name(text))
        }

        #expect(manager.recentUsernames.value.map(\.rawValue) == ["f", "e", "d", "c", "b"])
    }

    @Test func logOutKeepsRecents() {
        let manager = SessionManagerImpl(store: SessionStore(storageEngine: InMemoryStorageEngine()))
        manager.signIn(as: name("alice"))

        manager.logOut()

        #expect(manager.currentUsername.value == nil)
        #expect(manager.recentUsernames.value == [name("alice")])
    }

    @Test func managersSharingAStoreSeeEachOthersWrites() {
        let store = SessionStore(storageEngine: InMemoryStorageEngine())
        let signInSession = SessionManagerImpl(store: store)
        let userSession = SessionManagerImpl(store: store)

        signInSession.signIn(as: name("alice"))
        #expect(userSession.currentUsername.value == name("alice"))

        userSession.logOut()
        #expect(signInSession.currentUsername.value == nil)
    }
}
