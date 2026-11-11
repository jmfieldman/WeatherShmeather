//
//  SlateManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import Slate
import SlateSchema

/// Vends configured `Slate<Schema>` instances. The manager caches handles by
/// schema so repeated requests for the same `SlateSchema` return the same
/// underlying SQLite store.
///
/// Implementations are responsible for:
///  * Deriving a stable on-disk path from `Schema.schemaIdentifier`.
///  * Routing the store under the appropriate document silo
///    (per-user by default, or the transient silo
///    when `transientEnvironment` is `true`).
///  * Calling `Slate.configure()` before returning, so callers receive a
///    ready-to-use handle.
///  * Choosing a `SlateStoreKind`. `.cacheStore` causes Slate to wipe and
///    recreate an incompatible store on disk, which is the right default
///    for client-side caches; `.strict` propagates the open error instead.
@MainActor
public protocol SlateManager: AnyObject, Sendable {
    /// Provide a configured `Slate<Schema>` for `schema`.
    ///
    /// The handle is cached on the underlying database path; subsequent
    /// requests for the same `Schema` (in the same silo) return the same
    /// handle.
    ///
    /// - Parameters:
    ///   - schema: The generated `SlateSchema` enum. `Schema.schemaIdentifier`
    ///     drives the on-disk filename.
    ///   - transientEnvironment: When `true`, the store is rooted in the
    ///     transient (`AppEnvironment.transient`) silo and cached
    ///     process-wide. When `false`, it is rooted in the injected
    ///     `AppEnvironment`'s per-user silo and cached on the manager
    ///     instance.
    ///   - storeKind: `.cacheStore` to wipe-and-retry on an incompatible
    ///     SQLite store, `.strict` to surface the error. Every store in this app
    ///     uses `.cacheStore`.
    /// - Returns: A `Slate<Schema>` whose `configure()` has already
    ///   completed.
    func provide<Schema: SlateSchema>(
        for schema: Schema.Type,
        transientEnvironment: Bool,
        storeKind: SlateStoreKind,
    ) -> Slate<Schema>
}

public extension SlateManager {
    /// Convenience overload that uses the per-user environment and
    /// `.cacheStore` semantics. Most callers want this.
    func provide<Schema: SlateSchema>(for schema: Schema.Type) -> Slate<Schema> {
        provide(
            for: schema,
            transientEnvironment: false,
            storeKind: .cacheStore,
        )
    }
}
