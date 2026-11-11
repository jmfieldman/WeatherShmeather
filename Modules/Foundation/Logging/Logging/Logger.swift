//
//  Logger.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import Foundation
import os
import Slate
import UIKit

/// Minimum level at which a `Log()` call is persisted. `MIN_LOG_LEVEL` is the
/// scheme-injected override used to silence noisy levels in CI / tests.
let kMinLogLevel: Int = ProcessInfo.processInfo
    .environment["MIN_LOG_LEVEL"]
    .flatMap { Int($0) } ?? 1

/// File-private lock holding the most recent foreground mark. Lives outside
/// the `Logger` class so `Log()` — which is callable from any isolation
/// context — can read it without a hop to the main actor.
private let foregroundMarkLock = OSAllocatedUnfairLock<Date>(initialState: Date())

/// The one shared formatter used for the `os_log` mirror; kept here (not in
/// the class) so `Log()` can format without touching main-actor state.
/// `ISO8601DateFormatter` is documented as thread-safe, so `nonisolated(unsafe)`
/// is correct for Swift 6 strict concurrency.
private nonisolated(unsafe) let logDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

/// Persist a log entry. Safe to call from any isolation context — MainActor,
/// another actor, a detached task, or nonisolated code. The call site never
/// awaits disk I/O; the entry is handed off to a background writer.
///
/// Requires `Logger.start()` to have been called on the main actor at app
/// launch. Calls made before `start()` are silently dropped.
public func Log(
    _ context: LogContext,
    _ level: LogLevel,
    _ message: @autoclosure () -> LogMessage,
    tags: [String]? = nil,
    metadata: (any Encodable)? = nil,
    sensitiveOverride: @autoclosure () -> LogMessage? = nil,
    filePath: String = #file,
    function: String = #function,
    line: Int = #line,
) {
    guard level.rawValue >= kMinLogLevel, let logger = Logger.shared else {
        return
    }

    logger.log(
        context: context,
        level: level,
        message: message(),
        tags: tags,
        metadata: metadata,
        sensitiveOverride: sensitiveOverride(),
        filePath: filePath,
        function: function,
        line: line,
    )
}

public final class Logger: @unchecked Sendable {
    /// Populated exactly once by `start()` on the main actor at app launch;
    /// read from any isolation thereafter. `nonisolated(unsafe)` is
    /// justified by that single-writer-then-read-only invariant.
    nonisolated(unsafe) static var shared: Logger?

    /// Captured once at launch; `processUptime` on each entry is measured
    /// against this.
    let uptimeMark: Date

    let writer: LogWriter

    @MainActor
    public static func start() {
        guard shared == nil else {
            return
        }

        shared = Logger()
    }

    @MainActor
    private init() {
        let env = AppEnvironment(userId: nil)
        let storeDirUrl = env.documentSiloUrl
            .appending(path: "Logging", directoryHint: .isDirectory)
        let storeUrl = storeDirUrl
            .appending(component: "logging.sqlite", directoryHint: .notDirectory)

        // Slate's pure init won't create the parent directory; the Core Data
        // store open in `configure()` would fail without it.
        try? FileManager.default.createDirectory(at: storeDirUrl, withIntermediateDirectories: true)

        // Logging is foundational and can't take a dependency on
        // `SlateManager`, so we drive the runtime directly. `.cacheStore`
        // means an incompatible store on disk is wiped and recreated rather
        // than crashing the process — the right policy for log data.
        let slate = Slate<LoggingSlateSchema>(storeURL: storeUrl, storeKind: .cacheStore)
        try? slate.configure()

        self.uptimeMark = Date()
        self.writer = LogWriter(slate: slate)

        Task { @MainActor [writer] in
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.willResignActiveNotification,
            ) {
                let cutoff = Date().timeIntervalSince1970 - 60 * 60 * 24
                await writer.prune(olderThan: cutoff)
                await writer.flush()
            }
        }

        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.willEnterForegroundNotification,
            ) {
                foregroundMarkLock.withLock { $0 = Date() }
            }
        }
    }

    func log(
        context: LogContext,
        level: LogLevel,
        message: LogMessage,
        tags: [String]?,
        metadata: (any Encodable)?,
        sensitiveOverride: LogMessage?,
        filePath: String,
        function: String,
        line: Int,
    ) {
        let now = Date()
        let messageString = message.rawValue
        let sensitiveOverrideString = sensitiveOverride?.rawValue
        let foregroundMark = foregroundMarkLock.withLock { $0 }
        let foregroundUptime = now.timeIntervalSince(foregroundMark)
        let processUptime = now.timeIntervalSince(uptimeMark)

        let metadataString: String? = metadata.flatMap {
            (try? JSONEncoder().encode($0)).flatMap { String(data: $0, encoding: .utf8) }
        }

        let values = LogValues(
            clientId: UUID(),
            context: context.rawValue,
            level: Int16(level.rawValue),
            levelString: level.description,
            message: messageString,
            metadata: metadataString,
            sensitiveOverride: sensitiveOverrideString,
            tags: tags?.joined(separator: ","),
            file: (filePath as NSString).lastPathComponent,
            function: function,
            line: Int64(line),
            unixTimestamp: now.timeIntervalSince1970,
            foregroundUptime: foregroundUptime,
            processUptime: processUptime,
        )

        Task { [writer] in
            await writer.append(values)
        }

        #if DEBUG
        os_log(
            level.oslogType,
            log: .default,
            "%{public}@ [%{public}@] [%{public}@] -> %{public}@",
            logDateFormatter.string(from: now),
            context.rawValue,
            level.description,
            messageString,
        )
        #endif
    }
}
