//
//  SlateManagerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import Foundation
import Inject
import Logging
import Slate
import SlateManager
import SlateSchema

/// The subdirectory inside a document silo that contains all Slate stores
/// vended by this manager.
private let kSlateSiloDirectory = "slate"

/// Filesystem-illegal characters replaced when deriving a SQLite filename
/// from `Schema.schemaIdentifier`, which is normally already a Swift
/// identifier.
private let kIllegalNameCharacters: CharacterSet =
    .init(charactersIn: "/\\?%*:|\"<>,.")
        .union(.whitespacesAndNewlines)
        .union(.illegalCharacters)
        .union(.controlCharacters)

/// The concrete `SlateManager`. See `SlateManager` for the public contract.
///
/// Caching strategy:
///  * **Per-user handles** live in `instanceCache` and share the lifetime
///    of this impl. Re-creating the impl (after a sign-in or log out swaps
///    the injected `AppEnvironment`) drops every per-user handle.
///  * **Transient handles** live in `transientCache`, a
///    process-lifetime static. They survive impl re-creation, which is
///    what you want for stores that aren't tied to any user session.
///
/// Both maps use `strongToWeakObjects` so handles can be deallocated when
/// no caller still holds them. Slate's internal store registry guarantees
/// a single Core Data stack per file URL, so re-creating a handle after a
/// drop is cheap and correct.
@MainActor
public final class SlateManagerImpl: SlateManager {
    private let appEnvironment: AppEnvironment = Inject()

    private let instanceCache = NSMapTable<NSString, AnyObject>.strongToWeakObjects()

    private static let transientCache = NSMapTable<NSString, AnyObject>.strongToWeakObjects()

    public init() {}

    public func provide<Schema: SlateSchema>(
        for schema: Schema.Type,
        transientEnvironment: Bool,
        storeKind: SlateStoreKind,
    ) -> Slate<Schema> {
        let name = Self.sanitize(Schema.schemaIdentifier)
        let siloUrl = transientEnvironment
            ? AppEnvironment.transient.documentSiloUrl
            : appEnvironment.documentSiloUrl

        let storeDirUrl = siloUrl
            .appending(component: kSlateSiloDirectory, directoryHint: .isDirectory)
            .appending(component: name, directoryHint: .isDirectory)
        let storeUrl = storeDirUrl.appending(component: "\(name).sqlite", directoryHint: .notDirectory)

        let cacheKey = NSString(string: storeUrl.path)
        let cache = transientEnvironment ? Self.transientCache : instanceCache

        if let existing = cache.object(forKey: cacheKey) as? Slate<Schema> {
            return existing
        }

        try? FileManager.default.createDirectory(at: storeDirUrl, withIntermediateDirectories: true)

        let slate = Slate<Schema>(storeURL: storeUrl, storeKind: storeKind)
        do {
            try slate.configure()
        } catch {
            Log(.system, .error, "Failed to configure slate store: \(error.localizedDescription)")
        }

        cache.setObject(slate, forKey: cacheKey)
        return slate
    }

    private static func sanitize(_ s: String) -> String {
        s.unicodeScalars
            .map { kIllegalNameCharacters.contains($0) ? "_" : String($0) }
            .joined()
    }
}
