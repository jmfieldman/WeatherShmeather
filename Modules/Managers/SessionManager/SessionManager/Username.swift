//
//  Username.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// A normalized username, which is also the user id and the name of the
/// user's silo directory. The only way to make one is from text that passes
/// validation, so the sign-in screen and the silo can never disagree.
public struct Username: Hashable, Codable, Sendable, CustomStringConvertible {
    public static let maxLength = 32

    public let rawValue: String

    /// Trims and lowercases `text`, and returns `nil` unless the result is 1
    /// to 32 characters of `a-z`, `0-9`, `-` and `_`, starting with a letter
    /// or digit. Names starting with `_` are reserved for the app's own silos.
    public init?(_ text: String) {
        let normalized = Self.normalize(text)
        guard Self.isValidNormalized(normalized) else {
            return nil
        }

        self.rawValue = normalized
    }

    public var description: String {
        rawValue
    }

    /// Stored as a plain string, and validated again when read back.
    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let username = Username(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid username"))
        }

        self = username
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// What `text` becomes after trimming and lowercasing, valid or not.
    public static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private static let leadingCharacters = Set("abcdefghijklmnopqrstuvwxyz0123456789")
    private static let allowedCharacters = leadingCharacters.union("-_")

    private static func isValidNormalized(_ text: String) -> Bool {
        guard
            (1 ... maxLength).contains(text.count),
            let first = text.first,
            leadingCharacters.contains(first)
        else {
            return false
        }

        return text.allSatisfy { allowedCharacters.contains($0) }
    }
}
