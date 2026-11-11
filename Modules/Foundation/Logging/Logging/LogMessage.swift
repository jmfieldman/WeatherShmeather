//
//  LogMessage.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

public struct LogMessage: ExpressibleByStringInterpolation, Sendable {
    public typealias StringLiteralType = String
    public typealias StringInterpolation = LogMessageStringInterpolation

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(stringInterpolation: LogMessageStringInterpolation) {
        self.init(rawValue: stringInterpolation.output)
    }

    public struct LogMessageStringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate private(set) var output: String = ""

        public init(literalCapacity: Int, interpolationCount: Int) {
            output.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            output += literal
        }

        @_disfavoredOverload
        public mutating func appendInterpolation(
            _ value: some Any,
        ) {
            appendLiteral(String(describing: value))
        }

        public mutating func appendInterpolation(
            _ value: (some Any)?,
        ) {
            guard let value else {
                appendLiteral("(nil)")
                return
            }

            appendLiteral(String(describing: value))
        }

        @_disfavoredOverload
        public mutating func appendInterpolation(
            _ value: (some CustomStringConvertible)?,
        ) {
            guard let value else {
                appendLiteral("(nil)")
                return
            }

            appendLiteral(value.description)
        }

        public mutating func appendInterpolation(
            _ value: (some CustomDebugStringConvertible)?,
        ) {
            guard let value else {
                appendLiteral("(nil)")
                return
            }

            appendLiteral(value.debugDescription)
        }
    }
}
