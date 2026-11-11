//
//  DesignTokens.swift
//  Copyright © 2026 WeatherShmeather.
//

import SwiftUI

/// Purpose-named colors. Screens use these and never a raw color, so a
/// palette change is made here once.
public enum DesignTokens {
    public static let screenBackground = Color(uiColor: .systemBackground)
    public static let groupedBackground = Color(uiColor: .secondarySystemBackground)
    public static let primaryText = Color(uiColor: .label)
    public static let secondaryText = Color(uiColor: .secondaryLabel)
    public static let tertiaryText = Color(uiColor: .tertiaryLabel)
    public static let accent = Color(uiColor: .systemBlue)
    public static let error = Color(uiColor: .systemRed)
    public static let separator = Color(uiColor: .separator)

    /// Weather-symbol layer colors. Multicolor SF Symbols draw clouds in
    /// white, which vanishes on a light background, so condition symbols
    /// use palette rendering with these instead.
    public static let symbolCloud = Color(uiColor: .systemGray3)
    public static let symbolSun = Color(uiColor: .systemYellow)

    /// The soft shadow used where a flat surface needs a little depth.
    public static let softShadow = Color.black.opacity(0.08)
}
