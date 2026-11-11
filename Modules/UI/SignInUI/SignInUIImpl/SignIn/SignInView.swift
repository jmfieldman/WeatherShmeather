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

@Observable @MainActor
public final class SignInViewModel {
    public let signInTask: SerialTask<Username, Void>
    public var text: String
    public var recentUsernames: [Username]

    /// The username to sign in as, or `nil` while the text isn't valid,
    /// which keeps the button disabled.
    public var submittableUsername: Username? {
        Username(text)
    }

    /// Only complain once there's something to complain about.
    public var showsValidationHint: Bool {
        !Username.normalize(text).isEmpty && submittableUsername == nil
    }

    public init(signInTask: SerialTask<Username, Void>, text: String = "", recentUsernames: [Username] = []) {
        self.signInTask = signInTask
        self.text = text
        self.recentUsernames = recentUsernames
    }
}

public struct SignInView: HostedView {
    @Bindable var viewModel: SignInViewModel
    @FocusState private var isFieldFocused: Bool

    public init(viewModel: SignInViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: .xl) {
                header
                form
                if !viewModel.recentUsernames.isEmpty {
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
            TextField(String.SignInUI.usernamePlaceholder, text: $viewModel.text)
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
                .opacity(viewModel.showsValidationHint ? 1 : 0)
                .accessibilityHidden(!viewModel.showsValidationHint)

            ActionButton(
                String.SignInUI.signInButton,
                task: viewModel.signInTask,
                input: viewModel.submittableUsername,
            )
        }
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: .s) {
            Text(String.SignInUI.recentHeader)
                .textStyle(.caption)
                .padding(.horizontal, .xs)
            VStack(spacing: 0) {
                ForEach(viewModel.recentUsernames, id: \.self) { username in
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
                    if username != viewModel.recentUsernames.last {
                        Divider().padding(.leading, .m)
                    }
                }
            }
            .background(DesignTokens.groupedBackground, in: .rect(cornerRadius: Radius.control))
        }
    }

    private func submit() {
        if let username = viewModel.submittableUsername {
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
            signInTask: SerialTask { _ in },
            recentUsernames: ["alice", "bob"].compactMap(Username.init),
        )
    }
}
