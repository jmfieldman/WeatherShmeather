//
//  AppEnvironment+Test.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import CocoaEx
import Foundation
import SwiftAsyncEx

@MainActor
public extension AppEnvironment {
    /// An environment that touches neither the keychain nor the app's documents.
    static func test(
        userId: String? = "tester",
        app: App? = nil,
        urlSession: URLSession? = nil,
        siloUrl: URL? = nil,
        cacheSiloUrl: URL? = nil,
        propertyFileStore: PersistentPropertyStorageEngine? = nil,
        propertyKeychainStore: PersistentPropertyStorageEngine? = nil,
    ) -> AppEnvironment {
        AppEnvironment(
            userId: userId,
            app: app,
            documentSiloUrl: siloUrl ?? FileManager.default
                .temporaryDirectory
                .appending(component: UUID().lowercaseUUIDString, directoryHint: .isDirectory),
            cacheSiloUrl: cacheSiloUrl ?? FileManager.default
                .temporaryDirectory
                .appending(component: UUID().lowercaseUUIDString, directoryHint: .isDirectory),
            propertyFileStore: propertyFileStore ?? InMemoryStorageEngine(),
            propertyKeychainStore: propertyKeychainStore ?? InMemoryStorageEngine(),
            urlSession: urlSession,
        )
    }
}
