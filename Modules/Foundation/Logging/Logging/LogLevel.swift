//
//  LogLevel.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import os

public enum LogLevel: Int, Codable, CustomStringConvertible, CaseIterable, Sendable {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case fatal = 5

    public var description: String {
        switch self {
        case .trace: "trace"
        case .debug: "debug"
        case .info: "info"
        case .warning: "warning"
        case .error: "error"
        case .fatal: "fatal"
        }
    }

    var oslogType: OSLogType {
        switch self {
        case .trace, .debug, .info: .default
        case .warning: .error
        case .error, .fatal: .fault
        }
    }
}
