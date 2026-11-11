//
//  SignInView.swift
//  Copyright © 2026 WeatherShmeather.
//

import DesignSystem
import SessionManager
import SFSafeSymbols
import SignInUIResources
import SwiftAsyncEx
import SwiftUI
import SwiftUIEx

/// What the sign-in view reads, and what it can ask for.
@Observable @MainActor
public final class SignInViewModel {
    public let text: Property<String>
    public let recentUsernames: Property<[Username]>
    /// The username to sign in as, or `nil` while the text isn't valid,
    /// which keeps the button disabled.
    public let submittableUsername: Property<Username?>
    /// Only complain once there's something to complain about.
    public let showsValidationHint: Property<Bool>

    public let textTask: SerialTask<String, Void>
    public let signInTask: SerialTask<Username, Void>

    public init(
        text: Property<String> = .constant(""),
        recentUsernames: Property<[Username]> = .constant([]),
        submittableUsername: Property<Username?> = .constant(nil),
        showsValidationHint: Property<Bool> = .constant(false),
        textTask: SerialTask<String, Void> = SerialTask { _ in },
        signInTask: SerialTask<Username, Void> = SerialTask { _ in },
    ) {
        self.text = text
        self.recentUsernames = recentUsernames
        self.submittableUsername = submittableUsername
        self.showsValidationHint = showsValidationHint
        self.textTask = textTask
        self.signInTask = signInTask
    }
}

public struct SignInView: HostedView {
    let viewModel: SignInViewModel
    @FocusState private var isFieldFocused: Bool

    public init(viewModel: SignInViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: .xl) {
                header
                form
                if !viewModel.recentUsernames.value.isEmpty {
                    recents
                }
            }
            .padding(.horizontal, .gutter)
            .padding(.top, .xxl)
            .padding(.bottom, .l)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignTokens.screenBackground)
    }

    private var header: some View {
        VStack(spacing: .m) {
            Image(systemSymbol: .cloudSunFill)
                .symbolRenderingMode(.palette)
                .foregroundStyle(DesignTokens.symbolCloud, DesignTokens.symbolSun)
                .font(TextStyle.display.font)
                .accessibilityHidden(true)
            Text(String.SignInUI.signInTitle)
                .textStyle(.hero)
                .accessibilityAddTraits(.isHeader)
            Text(String.SignInUI.signInSubtitle)
                .textStyle(.callout, color: DesignTokens.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: .s) {
            TextField(String.SignInUI.usernamePlaceholder, text: text)
                .textStyle(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .submitLabel(.go)
                .focused($isFieldFocused)
                .onSubmit(submit)
                .padding(.horizontal, .m)
                .frame(minHeight: ControlHeight.primary)
                .background(DesignTokens.groupedBackground, in: .rect(cornerRadius: Radius.control))

            Text(String.SignInUI.usernameInvalid)
                .textStyle(.caption, color: DesignTokens.error)
                .opacity(viewModel.showsValidationHint.value ? 1 : 0)
                .accessibilityHidden(!viewModel.showsValidationHint.value)

            ActionButton(
                String.SignInUI.signInButton,
                task: viewModel.signInTask,
                input: viewModel.submittableUsername.value,
            )
        }
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: .s) {
            Text(String.SignInUI.recentHeader)
                .textStyle(.caption)
                .padding(.horizontal, .xs)
            VStack(spacing: 0) {
                ForEach(viewModel.recentUsernames.value, id: \.self) { username in
                    Button {
                        viewModel.signInTask.fire(username)
                    } label: {
                        HStack(spacing: .m) {
                            Image(systemSymbol: .personCropCircle)
                                .foregroundStyle(DesignTokens.accent)
                            Text(username.rawValue)
                                .textStyle(.body)
                            Spacer()
                            Image(systemSymbol: .chevronRight)
                                .textStyle(.caption)
                        }
                        .padding(.horizontal, .m)
                        .frame(minHeight: ControlHeight.primary)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.signInTask.isExecuting)
                    if username != viewModel.recentUsernames.value.last {
                        Divider().padding(.leading, .m)
                    }
                }
            }
            .background(DesignTokens.groupedBackground, in: .rect(cornerRadius: Radius.control))
        }
    }

    /// The field shows the screen's text and reports edits as requests.
    private var text: Binding<String> {
        Binding(get: { viewModel.text.value }, set: { viewModel.textTask.fire($0) })
    }

    private func submit() {
        if let username = viewModel.submittableUsername.value {
            viewModel.signInTask.fire(username)
        }
    }
}

#Preview("Light") {
    SignInView(viewModel: .preview)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SignInView(viewModel: .preview)
        .preferredColorScheme(.dark)
}

private extension SignInViewModel {
    static var preview: SignInViewModel {
        SignInViewModel(
            recentUsernames: .constant(["alice", "bob"].compactMap(Username.init)),
        )
    }
}
