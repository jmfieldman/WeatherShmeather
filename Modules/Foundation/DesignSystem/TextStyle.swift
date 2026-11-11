//
//  TextStyle.swift
//  Copyright © 2026 WeatherShmeather.
//

import SwiftUI

/// The app's type scale. Screens apply a style with `.textStyle(_:)` and
/// never chain `.font(...)` themselves. Every style is built on a Dynamic
/// Type text style, so it scales with the user's text size.
public enum TextStyle {
    /// The huge, light numerals of a temperature reading.
    case display
    /// A screen's single most important line, such as the app name on sign-in.
    case hero
    case title
    case headline
    case body
    case callout
    case caption
    case finePrint

    public var font: Font {
        switch self {
        case .display: .system(size: 96, weight: .thin, design: .rounded)
        case .hero: .system(.largeTitle, design: .rounded, weight: .bold)
        case .title: .system(.title2, design: .rounded, weight: .semibold)
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .caption: .caption
        case .finePrint: .caption2
        }
    }

    public var color: Color {
        switch self {
        case .display, .hero, .title, .headline, .body, .callout: DesignTokens.primaryText
        case .caption, .finePrint: DesignTokens.secondaryText
        }
    }
}

public extension View {
    /// Applies a style's font and color. Pass `color` to override the
    /// style's color: a `.foregroundStyle` applied afterwards would not, since
    /// the innermost foreground style wins.
    func textStyle(_ style: TextStyle, color: Color? = nil) -> some View {
        font(style.font).foregroundStyle(color ?? style.color)
    }
}
