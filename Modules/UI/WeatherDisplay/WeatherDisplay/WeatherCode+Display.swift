//
//  WeatherCode+Display.swift
//  Copyright © 2026 WeatherShmeather.
//

import DesignSystem
import ForecastManager
import SFSafeSymbols
import SwiftUI
import WeatherDisplayResources

public extension WeatherCode {
    /// The condition's name, such as "Partly Cloudy". Clear skies say "Sunny"
    /// by day and "Clear" by night.
    func name(isDay: Bool) -> String {
        switch self {
        case .clear: isDay ? .WeatherDisplay.conditionSunny : .WeatherDisplay.conditionClear
        case .mainlyClear: isDay ? .WeatherDisplay.conditionMainlySunny : .WeatherDisplay.conditionMainlyClear
        case .partlyCloudy: .WeatherDisplay.conditionPartlyCloudy
        case .overcast: .WeatherDisplay.conditionOvercast
        case .fog: .WeatherDisplay.conditionFog
        case .drizzle: .WeatherDisplay.conditionDrizzle
        case .freezingDrizzle: .WeatherDisplay.conditionFreezingDrizzle
        case .rain: .WeatherDisplay.conditionRain
        case .heavyRain: .WeatherDisplay.conditionHeavyRain
        case .freezingRain: .WeatherDisplay.conditionFreezingRain
        case .snow: .WeatherDisplay.conditionSnow
        case .heavySnow: .WeatherDisplay.conditionHeavySnow
        case .rainShowers: .WeatherDisplay.conditionRainShowers
        case .snowShowers: .WeatherDisplay.conditionSnowShowers
        case .thunderstorm: .WeatherDisplay.conditionThunderstorm
        case .thunderstormWithHail: .WeatherDisplay.conditionThunderstormHail
        case .unknown: .WeatherDisplay.conditionUnknown
        }
    }

    /// The SF Symbol for the condition, with a night variant where one exists.
    func symbol(isDay: Bool) -> SFSymbol {
        switch self {
        case .clear: isDay ? .sunMaxFill : .moonStarsFill
        case .mainlyClear, .partlyCloudy: isDay ? .cloudSunFill : .cloudMoonFill
        case .overcast, .unknown: .cloudFill
        case .fog: .cloudFogFill
        case .drizzle: .cloudDrizzleFill
        case .freezingDrizzle, .freezingRain: .cloudSleetFill
        case .rain: .cloudRainFill
        case .heavyRain: .cloudHeavyrainFill
        case .snow, .heavySnow, .snowShowers: .cloudSnowFill
        case .rainShowers: isDay ? .cloudSunRainFill : .cloudMoonRainFill
        case .thunderstorm: .cloudBoltRainFill
        case .thunderstormWithHail: .cloudHailFill
        }
    }

    /// The flat background color for a card or page showing this condition.
    func background(isDay: Bool) -> Color {
        switch self {
        case .clear, .mainlyClear, .partlyCloudy, .unknown:
            isDay ? ConditionPalette.clearDay : ConditionPalette.clearNight
        case .overcast:
            isDay ? ConditionPalette.cloudyDay : ConditionPalette.cloudyNight
        case .fog:
            ConditionPalette.fog
        case .drizzle, .freezingDrizzle, .rain, .heavyRain, .freezingRain, .rainShowers:
            isDay ? ConditionPalette.rainDay : ConditionPalette.rainNight
        case .snow, .heavySnow, .snowShowers:
            isDay ? ConditionPalette.snowDay : ConditionPalette.snowNight
        case .thunderstorm, .thunderstormWithHail:
            ConditionPalette.storm
        }
    }
}

/// A condition symbol in its multicolor variant. On a condition background
/// the white clouds read well.
public struct ConditionSymbol: View {
    let code: WeatherCode
    let isDay: Bool

    public init(code: WeatherCode, isDay: Bool) {
        self.code = code
        self.isDay = isDay
    }

    public var body: some View {
        Image(systemSymbol: code.symbol(isDay: isDay))
            .symbolRenderingMode(.multicolor)
            .accessibilityLabel(code.name(isDay: isDay))
    }
}

public extension String {
    /// "H:84°  L:58°".
    static func highLow(high: String, low: String) -> String {
        .WeatherDisplay.highLow(high, low)
    }
}
