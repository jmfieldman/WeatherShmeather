//
//  MockSlateManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import CocoaEx
import Foundation
import Slate
import SlateManager
import SlateSchema

/// Vends real Slate stores in a temporary directory unique to this mock, so
/// each test starts empty. Repeated requests for a schema return the same store.
@MainActor
public final class MockSlateManager: SlateManager {
    private let directory = FileManager.default
        .temporaryDirectory
        .appending(component: UUID().lowercaseUUIDString, directoryHint: .isDirectory)
    private var stores: [String: AnyObject] = [:]

    public init() {}

    public func provide<Schema: SlateSchema>(
        for schema: Schema.Type,
        transientEnvironment: Bool,
        storeKind: SlateStoreKind,
    ) -> Slate<Schema> {
        if let existing = stores[Schema.schemaIdentifier] as? Slate<Schema> {
            return existing
        }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let slate = Slate<Schema>(
            storeURL: directory.appending(component: "\(Schema.schemaIdentifier).sqlite", directoryHint: .notDirectory),
            storeKind: storeKind,
        )
        try? slate.configure()
        stores[Schema.schemaIdentifier] = slate
        return slate
    }
}
