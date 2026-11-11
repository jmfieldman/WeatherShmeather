//
//  Spacing.swift
//  Copyright © 2026 WeatherShmeather.
//

import CoreGraphics

/// Spacing tokens. Screens use these and never a literal number.
public extension CGFloat {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    /// The horizontal margin between screen content and the screen edge.
    static let gutter: CGFloat = 20
}

/// Corner radius tokens.
public enum Radius {
    public static let control: CGFloat = 12
    public static let card: CGFloat = 20
}

/// Fixed control heights.
public enum ControlHeight {
    public static let primary: CGFloat = 52
}

/// Fixed row heights.
public enum RowHeight {
    /// The minimum height of a place card in the list.
    public static let card: CGFloat = 88
}
