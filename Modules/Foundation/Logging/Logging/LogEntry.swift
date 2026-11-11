//
//  LogEntry.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SlateSchema

/// Persisted log row backing the `Log()` API. One row per `Log()` call that
/// passes the `MIN_LOG_LEVEL` gate. Pruned to the most recent 24h on
/// `willResignActive` (see `Logger.start()`).
///
/// `@SlateEntity` requires `public`, but `LogEntry` is not part of the
/// `Logging` module's public surface — callers go through `Log()` and never
/// touch this type directly. The `public` modifier here is a constraint of
/// the macro, not an API decision.
@SlateEntity
public struct LogEntry {
    #Index<LogEntry>([\.unixTimestamp])

    public let clientId: UUID
    public let context: String
    public let level: Int16
    public let levelString: String
    public let message: String
    public let metadata: String?
    public let sensitiveOverride: String?
    public let tags: String?
    public let file: String
    public let function: String
    public let line: Int64
    public let unixTimestamp: Double
    public let foregroundUptime: Double
    public let processUptime: Double
}
