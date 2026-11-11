//
//  StoredMinutelyPrecipitation.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import SlateSchema

/// Precipitation for one 15-minute step of one place's next two hours.
@SlateEntity
public struct StoredMinutelyPrecipitation {
    #Index<StoredMinutelyPrecipitation>([\.placeId, \.time])

    public let placeId: String
    public let time: Date
    public let precipitation: Double
}
