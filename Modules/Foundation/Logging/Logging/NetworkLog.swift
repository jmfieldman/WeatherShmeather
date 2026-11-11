//
//  NetworkLog.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// A single HTTP request / response record kept in memory by `NetworkLogger`
/// for debug-only inspection. Not persisted to disk, not written to the
/// general `Log(...)` store. A future AdminUI can read these via
/// `NetworkLogger.shared.networkLogSnapshot()`.
public struct NetworkLog: Codable, Identifiable, Sendable {
    public let id: String
    public let service: String
    public let path: String
    public let method: String
    public let requestTimestamp: Date

    public internal(set) var params: String?
    public internal(set) var outstanding: Bool = true
    public internal(set) var error: String?
    public internal(set) var statusCode: Int?
    public internal(set) var responseTimestamp: Date?
    public internal(set) var responseBody: String?

    public init(id: String, service: String, path: String, method: String) {
        self.id = id
        self.service = service
        self.path = path
        self.method = method
        self.requestTimestamp = Date()
        self.params = nil
        self.error = nil
        self.statusCode = nil
        self.responseBody = nil
    }
}
