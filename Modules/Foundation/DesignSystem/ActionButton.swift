//
//  ActionButton.swift
//  Copyright © 2026 WeatherShmeather.
//

import SwiftAsyncEx
import SwiftUI

/// A full-width button bound to a `SerialTask`. It shows a spinner while the
/// task runs, and is disabled while it runs or while `input` is `nil`.
public struct ActionButton<Input: Sendable>: View {
    public enum Variant {
        /// The screen's main action: Liquid Glass, tinted with the accent.
        case primary
        /// A secondary action: plain Liquid Glass.
        case secondary
    }

    private let title: String
    private let task: SerialTask<Input, Void>
    private let input: Input?
    private let variant: Variant

    public init(_ title: String, task: SerialTask<Input, Void>, input: Input?, variant: Variant = .primary) {
        self.title = title
        self.task = task
        self.input = input
        self.variant = variant
    }

    public var body: some View {
        let button = Button {
            if let input {
                task.fire(input)
            }
        } label: {
            ZStack {
                Text(title)
                    .font(TextStyle.headline.font)
                    .opacity(task.isExecuting ? 0 : 1)
                if task.isExecuting {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: ControlHeight.primary)
        }
        .disabled(input == nil || task.isExecuting)

        switch variant {
        case .primary:
            button.buttonStyle(.glassProminent).tint(DesignTokens.accent)
        case .secondary:
            button.buttonStyle(.glass)
        }
    }
}

public extension ActionButton where Input == Void {
    init(_ title: String, task: SerialTask<Void, Void>, isEnabled: Bool = true, variant: Variant = .primary) {
        self.init(title, task: task, input: isEnabled ? () : nil, variant: variant)
    }
}
