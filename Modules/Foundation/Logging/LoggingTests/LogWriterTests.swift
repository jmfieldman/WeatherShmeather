//
//  LogWriterTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import CocoaEx
import Foundation
@testable import Logging
import Slate
import Testing

struct LogWriterTests {
    private func makeSlate() throws -> Slate<LoggingSlateSchema> {
        let directory = FileManager.default
            .temporaryDirectory
            .appending(component: UUID().lowercaseUUIDString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let slate = Slate<LoggingSlateSchema>(
            storeURL: directory.appending(component: "logging.sqlite", directoryHint: .notDirectory),
            storeKind: .cacheStore,
        )
        try slate.configure()
        return slate
    }

    private func makeValues(message: String, unixTimestamp: Double) -> LogValues {
        LogValues(
            clientId: UUID(),
            context: LogContext.system.rawValue,
            level: Int16(LogLevel.info.rawValue),
            levelString: LogLevel.info.description,
            message: message,
            metadata: nil,
            sensitiveOverride: nil,
            tags: nil,
            file: "LogWriterTests.swift",
            function: "test",
            line: 1,
            unixTimestamp: unixTimestamp,
            foregroundUptime: 0,
            processUptime: 0,
        )
    }

    @Test func flushWritesBufferedEntries() async throws {
        let slate = try makeSlate()
        let writer = LogWriter(slate: slate)

        await writer.append(makeValues(message: "one", unixTimestamp: 1))
        await writer.append(makeValues(message: "two", unixTimestamp: 2))
        await writer.flush()

        let entries = try await slate.many(LogEntry.self)
        #expect(entries.map(\.message).sorted() == ["one", "two"])
    }

    @Test func quietPeriodWritesBufferedEntries() async throws {
        let slate = try makeSlate()
        let writer = LogWriter(slate: slate)

        await writer.append(makeValues(message: "one", unixTimestamp: 1))
        try await Task.sleep(for: .seconds(1))

        let entries = try await slate.many(LogEntry.self)
        #expect(entries.map(\.message) == ["one"])
    }

    @Test func pruneRemovesOnlyOlderEntries() async throws {
        let slate = try makeSlate()
        let writer = LogWriter(slate: slate)

        await writer.append(makeValues(message: "old", unixTimestamp: 100))
        await writer.append(makeValues(message: "new", unixTimestamp: 300))
        await writer.flush()
        await writer.prune(olderThan: 200)

        let entries = try await slate.many(LogEntry.self)
        #expect(entries.map(\.message) == ["new"])
    }

    @Test func messageInterpolationShowsNil() {
        let missing: String? = nil
        let message: LogMessage = "value: \(missing)"
        #expect(message.rawValue == "value: (nil)")
    }
}
