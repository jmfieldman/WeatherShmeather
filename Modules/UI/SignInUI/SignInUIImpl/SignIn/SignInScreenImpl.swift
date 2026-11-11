//
//  SignInScreenImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import Inject
import SessionManager
import SignInUI
import SwiftAsyncEx
import SwiftUIEx
import UIKit

@MainActor
public final class SignInScreenImpl: HostingScreen<SignInScreenModel, SignInView>, SignInScreen {
    public convenience init(builder: SignInScreenBuilder) {
        self.init(controllerModel: SignInScreenModel())
    }
}

@MainActor
public final class SignInScreenModel: HostingScreenModel {
    public weak var viewController: UIViewController?
    public private(set) lazy var viewModel = SignInViewModel(
        text: Property(mirroring: text),
        recentUsernames: Property(mirroring: sessionManager.recentUsernames),
        submittableUsername: Property(tracking: { [text] in
            Username(text.value)
        }),
        showsValidationHint: Property(tracking: { [text] in
            !Username.normalize(text.value).isEmpty && Username(text.value) == nil
        }),
        textTask: .weak(self) { `self`, text in
            self.text.value = text
        },
        signInTask: .weak(self) { `self`, username in
            self.sessionManager.signIn(as: username)
        },
    )

    private let text = MutableProperty("")
    private let sessionManager: SessionManager = Inject()

    public init() {}
}
