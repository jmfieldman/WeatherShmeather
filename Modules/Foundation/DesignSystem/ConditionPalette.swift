//
//  ConditionPalette.swift
//  Copyright © 2026 WeatherShmeather.
//

import SwiftUI

/// The flat colors that stand in for weather imagery. Each place's card and
/// page takes one, chosen from its conditions and whether it's day or night.
/// Screens never use these directly; `WeatherDisplay` picks one per forecast.
public enum ConditionPalette {
    public static let clearDay = Color(red: 0.25, green: 0.56, blue: 0.93)
    public static let clearNight = Color(red: 0.09, green: 0.15, blue: 0.33)
    public static let cloudyDay = Color(red: 0.47, green: 0.55, blue: 0.64)
    public static let cloudyNight = Color(red: 0.18, green: 0.21, blue: 0.28)
    public static let rainDay = Color(red: 0.29, green: 0.40, blue: 0.53)
    public static let rainNight = Color(red: 0.13, green: 0.17, blue: 0.25)
    public static let snowDay = Color(red: 0.55, green: 0.66, blue: 0.78)
    public static let snowNight = Color(red: 0.22, green: 0.27, blue: 0.38)
    public static let storm = Color(red: 0.24, green: 0.22, blue: 0.36)
    public static let fog = Color(red: 0.56, green: 0.58, blue: 0.60)

    /// Text and icons drawn on any of the colors above.
    public static let foreground = Color.white
    public static let secondaryForeground = Color.white.opacity(0.75)
    /// Tracks and dividers on a condition color.
    public static let subtleForeground = Color.white.opacity(0.25)
}
