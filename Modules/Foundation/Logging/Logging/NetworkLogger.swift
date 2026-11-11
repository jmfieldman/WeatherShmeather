//
//  NetworkLogger.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// In-memory ring buffer of recent HTTP requests, intended for a future
/// debug / admin-UI surface. Safe to call from any isolation context; all
/// state is guarded by a serial `DispatchQueue`.
///
/// This is deliberately not wired into the disk-backed `Log(...)` store —
/// it is an ephemeral aid for inspecting live network traffic in-app, not
/// a crash-report attachment or persistent trace.
public final class NetworkLogger: @unchecked Sendable {
    public static let shared = NetworkLogger()

    /// How many network requests to keep in our in-memory log at any time.
    static let maxInMemoryLogCount: Int = 500

    /// How many requests to truncate when we breach the max count.
    static let inMemoryLogTruncateCount: Int = 50

    private let accessQueue = DispatchQueue(label: "NetworkLogger.accessQueue")
    private var outstandingRequests: [String: NetworkLog] = [:]
    private var inMemoryLog: [NetworkLog] = []

    private init() {}

    public func addOutstanding(request: NetworkLog, requestId: String) {
        accessQueue.sync {
            outstandingRequests[requestId] = request
        }
    }

    public func setParams(_ params: String?, requestId: String) {
        accessQueue.sync {
            outstandingRequests[requestId]?.params = params
        }
    }

    public func resolveOutstanding(
        requestId: String,
        statusCode: Int?,
        responseBody: String?,
        error: String?,
    ) {
        accessQueue.sync {
            guard var request = outstandingRequests[requestId] else {
                return
            }

            request.outstanding = false
            request.statusCode = statusCode
            request.responseBody = responseBody
            request.responseTimestamp = Date()
            request.error = error

            outstandingRequests.removeValue(forKey: requestId)

            inMemoryLog.append(request)

            if inMemoryLog.count > Self.maxInMemoryLogCount {
                inMemoryLog.removeFirst(Self.inMemoryLogTruncateCount)
            }
        }
    }

    /// Returns a snapshot of outstanding + completed requests, outstanding
    /// first and sorted newest-first within that group. Suitable for
    /// binding into a list UI.
    public func networkLogSnapshot() -> [NetworkLog] {
        accessQueue.sync {
            outstandingRequests.values.sorted(by: { $0.requestTimestamp > $1.requestTimestamp }) + inMemoryLog
        }
    }
}
