//
//  AppEnvironment.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SwiftAsyncEx

/// Everything scoped to one user session.
///
/// An `AppEnvironment` is registered into the injection container by the
/// session coordinator. Signing in or out resets the container and registers
/// a new environment, so every manager is rebuilt against the new user's
/// silos. That rebuild is the app's only mechanism for per-user isolation.
///
/// `userId == nil` is the transient environment used before anyone signs in:
/// it has its own silo, and managers built against it keep nothing per-user.
public final class AppEnvironment: Sendable {
    /// The signed-in user's id, which is their normalized username, or `nil`
    /// before sign-in.
    public let userId: String?

    /// Build and run-time facts about the app binary.
    public let app: App

    /// The silo directory name: the user id, or a reserved name for the
    /// transient environment. Usernames can't contain `_` at the start, so
    /// the reserved names never collide with a user.
    public let environmentId: String

    /// Per-user documents: Slate stores and persistent properties. Excluded
    /// from backup.
    public let documentSiloUrl: URL

    /// Per-user caches, which the OS may clear.
    public let cacheSiloUrl: URL

    /// Per-user `PersistentProperty` storage, as files in the document silo.
    public let propertyFileStore: PersistentPropertyStorageEngine

    /// Per-user `PersistentProperty` storage for secrets, in the keychain.
    public let propertyKeychainStore: PersistentPropertyStorageEngine

    /// The session every request goes through. Ephemeral, with no cookies
    /// and no URL cache, so any caching is a manager's explicit decision.
    public let urlSession: URLSession

    @MainActor public init(
        userId: String?,
        app: App? = nil,
        documentSiloUrl: URL? = nil,
        cacheSiloUrl: URL? = nil,
        propertyFileStore: PersistentPropertyStorageEngine? = nil,
        propertyKeychainStore: PersistentPropertyStorageEngine? = nil,
        urlSession: URLSession? = nil,
    ) {
        let resolvedApp = app ?? App()
        let resolvedEnvironmentId = Self.environmentId(userId: userId)
        let resolvedDocumentSiloUrl = documentSiloUrl ?? Self.detectedDocumentSiloUrl(environmentId: resolvedEnvironmentId)

        self.userId = userId
        self.app = resolvedApp
        self.environmentId = resolvedEnvironmentId
        self.documentSiloUrl = resolvedDocumentSiloUrl
        self.cacheSiloUrl = cacheSiloUrl ?? Self.detectedCacheSiloUrl(environmentId: resolvedEnvironmentId)
        self.propertyFileStore = propertyFileStore ?? Self.createPropertyFileStore(
            documentSiloUrl: resolvedDocumentSiloUrl,
        )
        self.propertyKeychainStore = propertyKeychainStore ?? Self.createPropertyKeychainStore(
            app: resolvedApp,
            environmentId: resolvedEnvironmentId,
        )
        self.urlSession = urlSession ?? Self.defaultURLSession
    }
}

public extension AppEnvironment {
    static let defaultURLSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    /// The one cross-user store, for what must be readable before any user's
    /// environment exists: who is signed in, and who has signed in before.
    static let globalPersistentPropertiesStore: PersistentPropertyStorageEngine = createPropertyFileStore(
        documentSiloUrl: detectedDocumentSiloUrl(environmentId: kGlobalEnvironmentId),
    )

    /// Deletes a user's document and cache silos. The caller must make sure
    /// that user's managers are no longer running.
    static func removeSilos(userId: String) {
        let environmentId = environmentId(userId: userId)
        try? FileManager.default.removeItem(at: siloRootUrl(for: .documentDirectory).appending(path: environmentId))
        try? FileManager.default.removeItem(at: siloRootUrl(for: .cachesDirectory).appending(path: environmentId))
    }

    var isSimulator: Bool {
        app.runEnvironment == .simulator
    }
}

private let kTransientEnvironmentId = "_transient_"
private let kGlobalEnvironmentId = "_global_"

private extension AppEnvironment {
    static func environmentId(userId: String?) -> String {
        userId ?? kTransientEnvironmentId
    }

    static func siloRootUrl(for directory: FileManager.SearchPathDirectory) -> URL {
        FileManager.default
            .urls(for: directory, in: .userDomainMask)
            .first!
            .appending(path: "silos", directoryHint: .isDirectory)
    }

    static func detectedDocumentSiloUrl(environmentId: String) -> URL {
        var siloUrl = siloRootUrl(for: .documentDirectory)

        // The exclude-from-backup attribute can only be applied to a path that
        // already exists on disk, so create the parent silos/ directory before
        // attempting to set the resource value.
        try? FileManager.default.createDirectory(at: siloUrl, withIntermediateDirectories: true, attributes: nil)
        var noBackup = URLResourceValues()
        noBackup.isExcludedFromBackup = true
        try? siloUrl.setResourceValues(noBackup)

        let environmentIdUrl = siloUrl.appending(path: environmentId, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: environmentIdUrl, withIntermediateDirectories: true, attributes: nil)

        return environmentIdUrl
    }

    static func detectedCacheSiloUrl(environmentId: String) -> URL {
        siloRootUrl(for: .cachesDirectory)
            .appending(path: environmentId, directoryHint: .isDirectory)
    }

    static func createPropertyFileStore(
        documentSiloUrl: URL,
    ) -> PersistentPropertyStorageEngine {
        let rootUrl = documentSiloUrl.appending(path: "PersistentProperties", directoryHint: .isDirectory)
        do {
            return try FileStorageEngine(rootDirectoryUrl: rootUrl)
        } catch {
            fatalError("Failed to create FileStorageEngine at \(rootUrl.path): \(error)")
        }
    }

    static func createPropertyKeychainStore(
        app: App,
        environmentId: String,
    ) -> PersistentPropertyStorageEngine {
        KeychainStorageEngine(
            service: environmentId,
            accessGroup: "\(app.appIdPrefix)\(app.bundleId)",
            synchronized: false,
        )
    }
}
