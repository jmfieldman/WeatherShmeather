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
    public private(set) lazy var viewModel: SignInViewModel = .init(
        signInTask: .weak(self) { `self`, username in
            self.sessionManager.signIn(as: username)
        },
    )

    private let sessionManager: SessionManager = Inject()

    public init() {
        Task.observe(bindTo: self) { [sessionManager] in
            sessionManager.recentUsernames.value
        } perform: { [weak self] recent in
            self?.viewModel.recentUsernames = recent
        }
    }
}
