//
//  RootTabViewControllerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import RootTabUI
import SFSafeSymbols
import UIKit

public final class RootTabViewControllerImpl: UITabBarController, RootTabViewController {
    // This controller is the window's root and is built before any user
    // session exists, so it must never `Inject()` at the top level.

    public required init(builder: RootTabViewControllerBuilder) {
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

    public func installNewViewControllers() {
        // The tab roots are placeholders until the Weather and Settings
        // screens exist; each will then be built from its screen's Builder.
        setTabs([
            makeTab(title: "Weather", symbol: .cloudSun, identifier: "weather", root: PlaceholderViewController(title: "Weather")),
            makeTab(title: "Settings", symbol: .gearshape, identifier: "settings", root: PlaceholderViewController(title: "Settings")),
        ], animated: false)
    }

    private func makeTab(
        title: String,
        symbol: SFSymbol,
        identifier: String,
        root: UIViewController,
    ) -> UITab {
        let navigationController = UINavigationController(rootViewController: root)
        return UITab(
            title: title,
            image: UIImage(systemSymbol: symbol),
            identifier: identifier,
            viewControllerProvider: { _ in navigationController },
        )
    }
}

/// Stands in for a tab's root screen until that screen is built.
private final class PlaceholderViewController: UIViewController {
    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
    }
}
