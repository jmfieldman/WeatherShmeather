//
//  RootViewControllerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import RootUI
import SignInUI
import UIKit

public final class RootViewControllerImpl: UIViewController, RootViewController {
    private var signInScreen: (any SignInScreen)?

    public required init(builder: RootViewControllerBuilder) {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    public func installSignInScreen() {
        if let signInScreen {
            signInScreen.willMove(toParent: nil)
            signInScreen.view.removeFromSuperview()
            signInScreen.removeFromParent()
        }

        let screen = SignInScreenBuilder().build()
        addChild(screen)
        screen.view.frame = view.bounds
        screen.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(screen.view)
        screen.didMove(toParent: self)
        signInScreen = screen
    }
}
