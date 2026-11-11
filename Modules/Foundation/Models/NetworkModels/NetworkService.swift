//
//  NetworkService.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// The Open-Meteo APIs the app talks to. Open-Meteo serves each API from its
/// own host, so a service is a base URL; the version segment lives on each
/// resource's path.
public enum NetworkService: String, Hashable, Codable, Sendable, CaseIterable {
    case forecast
    case geocoding
    case airQuality

    public var baseUrl: String {
        switch self {
        case .forecast: "https://api.open-meteo.com"
        case .geocoding: "https://geocoding-api.open-meteo.com"
        case .airQuality: "https://air-quality-api.open-meteo.com"
        }
    }
}
