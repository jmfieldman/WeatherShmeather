//
//  LogContext.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// The subsystem a log entry belongs to. Kept as a closed enum so call sites
/// can be grepped and the set of valid contexts reviewed at a glance; grow
/// this list as new subsystems come online.
public enum LogContext: String, Codable, CaseIterable, Sendable {
    case forecast = "Forecast"
    case location = "Location"
    case network = "Network"
    case places = "Places"
    case preferences = "Preferences"
    case session = "Session"
    case system = "System"
}
