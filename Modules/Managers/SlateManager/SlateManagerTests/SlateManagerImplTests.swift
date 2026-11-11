//
//  SlateManagerImplTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import AppEnvironmentTestHelpers
import CocoaEx
import Foundation
import Inject
import Logging
import Slate
import SlateManager
import SlateManagerImpl
import SlateManagerTestHelpers
import Testing

@MainActor
struct SlateManagerImplTests {
    private func makeManager(siloUrl: URL) -> SlateManagerImpl {
        let environment = AppEnvironment.test(siloUrl: siloUrl)
        InjectionManager.register(AppEnvironment.self) { environment }
        InjectionManager.resetCurrentContainer()
        return SlateManagerImpl()
    }

    private func makeSiloUrl() -> URL {
        FileManager.default
            .temporaryDirectory
            .appending(component: UUID().lowercaseUUIDString, directoryHint: .isDirectory)
    }

    private func insertEntry(into slate: Slate<LoggingSlateSchema>) async throws {
        try await slate.mutate { context in
            let row = context.create(DatabaseLogEntry.self)
            row.clientId = UUID()
            row.context = LogContext.system.rawValue
            row.level = 0
            row.levelString = ""
            row.message = ""
            row.file = ""
            row.function = ""
            row.line = 0
            row.unixTimestamp = 0
            row.foregroundUptime = 0
            row.processUptime = 0
        }
    }

    @Test func returnsTheSameStoreForASchema() {
        let manager = makeManager(siloUrl: makeSiloUrl())

        let first = manager.provide(for: LoggingSlateSchema.self)
        let second = manager.provide(for: LoggingSlateSchema.self)

        #expect(first === second)
    }

    @Test func storesAreIsolatedBySilo() async throws {
        let firstSlate = makeManager(siloUrl: makeSiloUrl()).provide(for: LoggingSlateSchema.self)
        try await insertEntry(into: firstSlate)

        let secondSlate = makeManager(siloUrl: makeSiloUrl()).provide(for: LoggingSlateSchema.self)

        #expect(try await firstSlate.count(LogEntry.self) == 1)
        #expect(try await secondSlate.count(LogEntry.self) == 0)
    }

    @Test func mockStartsEmptyAndReusesItsStore() async throws {
        let mock = MockSlateManager()

        let slate = mock.provide(for: LoggingSlateSchema.self)
        #expect(try await slate.count(LogEntry.self) == 0)
        #expect(slate === mock.provide(for: LoggingSlateSchema.self))
    }
}
