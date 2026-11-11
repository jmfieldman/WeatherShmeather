//
//  LogWriter.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import Slate

/// Plain sendable payload captured at the `Log()` call site. We build this on
/// the caller's executor and hand it off to `LogWriter` so the
/// `DatabaseLogEntry` row is only ever constructed inside `slate.mutate`,
/// where it's bound to the writer context.
struct LogValues: Sendable {
    let clientId: UUID
    let context: String
    let level: Int16
    let levelString: String
    let message: String
    let metadata: String?
    let sensitiveOverride: String?
    let tags: String?
    let file: String
    let function: String
    let line: Int64
    let unixTimestamp: Double
    let foregroundUptime: Double
    let processUptime: Double
}

/// Serializes Slate writes for the logging store onto a single background
/// actor. `append` buffers `LogValues` in memory; the buffer is drained into
/// one `slate.mutate` call either when it hits `flushAfterCount` or after
/// `flushAfterNanoseconds` of quiet, so a burst of `Log()` calls produces
/// one disk write rather than N.
actor LogWriter {
    /// Flush immediately once this many entries are pending. Bounds worst-case
    /// in-memory churn during a log burst.
    private static let flushAfterCount = 32

    /// If the pending buffer doesn't hit `flushAfterCount`, flush after this
    /// quiet period. Keeps logs visible on disk during idle periods without
    /// saving on every single append.
    private static let flushAfterNanoseconds: UInt64 = 250_000_000

    private let slate: Slate<LoggingSlateSchema>
    private var pendingValues: [LogValues] = []
    private var flushTask: Task<Void, Never>?

    init(slate: Slate<LoggingSlateSchema>) {
        self.slate = slate
    }

    func append(_ values: LogValues) {
        pendingValues.append(values)

        if pendingValues.count >= Self.flushAfterCount {
            Task { [weak self] in
                await self?.flushNow()
            }
            return
        }

        if flushTask == nil {
            flushTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.flushAfterNanoseconds)
                guard !Task.isCancelled else {
                    return
                }

                await self?.flushAfterQuietPeriod()
            }
        }
    }

    func flush() async {
        await flushNow()
    }

    func prune(olderThan cutoff: Double) async {
        // Top-level batch delete — runs on Slate's writer barrier and
        // bypasses any pending mutate context. If `configure()` hasn't
        // completed yet, this throws `notConfigured`; we silently swallow
        // because logging from inside the logger would feed back into the
        // same buffer.
        do {
            try await slate.batchDelete(LogEntry.self, where: \.unixTimestamp < cutoff)
        } catch {
            // intentionally silent
        }
    }

    /// Runs on `flushTask` itself, so it must clear the task before flushing.
    /// `flushNow` would otherwise cancel the task it is running on, and Slate
    /// refuses to write from a cancelled task.
    private func flushAfterQuietPeriod() async {
        flushTask = nil
        await flushNow()
    }

    private func flushNow() async {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingValues.isEmpty else {
            return
        }

        // Snapshot and clear up-front so concurrent appends during the
        // mutate `await` accumulate into the next batch. A failed write
        // drops the snapshot rather than retaining it — the `os_log` mirror still captured
        // every entry, so on-disk loss is recoverable from device logs.
        let batch = pendingValues
        pendingValues.removeAll(keepingCapacity: true)

        do {
            try await slate.mutate { context in
                for values in batch {
                    let row = context.create(DatabaseLogEntry.self)
                    row.clientId = values.clientId
                    row.context = values.context
                    row.level = values.level
                    row.levelString = values.levelString
                    row.message = values.message
                    row.metadata = values.metadata
                    row.sensitiveOverride = values.sensitiveOverride
                    row.tags = values.tags
                    row.file = values.file
                    row.function = values.function
                    row.line = values.line
                    row.unixTimestamp = values.unixTimestamp
                    row.foregroundUptime = values.foregroundUptime
                    row.processUptime = values.processUptime
                }
            }
        } catch {
            // intentionally silent — see comment above
        }
    }
}
