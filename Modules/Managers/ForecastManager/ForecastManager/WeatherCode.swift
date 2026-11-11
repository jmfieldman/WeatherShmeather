//
//  WeatherCode.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// The WMO weather interpretation codes Open-Meteo reports, grouped into the
/// conditions the app shows.
public enum WeatherCode: Hashable, Sendable, CaseIterable {
    case clear
    case mainlyClear
    case partlyCloudy
    case overcast
    case fog
    case drizzle
    case freezingDrizzle
    case rain
    case heavyRain
    case freezingRain
    case snow
    case heavySnow
    case rainShowers
    case snowShowers
    case thunderstorm
    case thunderstormWithHail
    case unknown

    public init(wmoCode: Int) {
        self =
            switch wmoCode {
            case 0: .clear
            case 1: .mainlyClear
            case 2: .partlyCloudy
            case 3: .overcast
            case 45, 48: .fog
            case 51, 53, 55: .drizzle
            case 56, 57: .freezingDrizzle
            case 61, 63: .rain
            case 65: .heavyRain
            case 66, 67: .freezingRain
            case 71, 73, 77: .snow
            case 75: .heavySnow
            case 80, 81, 82: .rainShowers
            case 85, 86: .snowShowers
            case 95: .thunderstorm
            case 96, 99: .thunderstormWithHail
            default: .unknown
            }
    }

    /// Whether the condition involves falling rain, snow, or similar.
    public var isPrecipitation: Bool {
        switch self {
        case .drizzle, .freezingDrizzle, .rain, .heavyRain, .freezingRain, .snow, .heavySnow,
             .rainShowers, .snowShowers, .thunderstorm, .thunderstormWithHail:
            true
        case .clear, .mainlyClear, .partlyCloudy, .overcast, .fog, .unknown:
            false
        }
    }
}
