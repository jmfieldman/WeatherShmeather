//
//  ErrorDialogProviding.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// User-facing copy for an error. Every manager's typed error conforms, so a
/// screen model can show any failure without knowing its type.
public protocol ErrorDialogProviding {
    var errorTitle: String { get }
    var errorBody: String { get }
}
