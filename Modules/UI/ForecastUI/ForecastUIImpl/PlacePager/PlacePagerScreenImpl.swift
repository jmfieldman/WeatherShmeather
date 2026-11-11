//
//  PlacePagerScreenImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import ForecastUI
import ForecastUIResources
import Foundation
import Inject
import PlacesManager
import SFSafeSymbols
import SwiftAsyncEx
import UIKit

/// The pager is hand-rolled UIKit, the case the architecture allows for a
/// screen SwiftUI hosting doesn't fit: a `UIPageViewController` of ordinary
/// forecast screens, each built from its Builder, under a glass bottom bar.
/// It keeps a screen model, but no SwiftUI view model.
@MainActor
public final class PlacePagerScreenImpl: UIViewController, PlacePagerScreen {
    private let model: PlacePagerScreenModel
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    private let pageControl = UIPageControl()
    private let listButton = UIButton(configuration: .glass())

    /// Pages built so far, by place id, so swiping back reuses them.
    private var pages: [String: any PlaceForecastScreen] = [:]

    public required init(builder: PlacePagerScreenBuilder) {
        self.model = PlacePagerScreenModel(initialPlaceId: builder.initialPlaceId)
        super.init(nibName: nil, bundle: nil)
        model.viewController = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        addChild(pageViewController)
        pageViewController.view.frame = view.bounds
        pageViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        pageViewController.dataSource = self
        pageViewController.delegate = self

        installBottomBar()

        Task.observe(bindTo: self) { [model] in
            model.placeIds
        } perform: { [weak self] placeIds in
            self?.placesChanged(placeIds)
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: Bottom bar

    private func installBottomBar() {
        // A darker tint keeps the white dots readable on light condition colors.
        let glass = UIGlassEffect()
        glass.tintColor = UIColor.black.withAlphaComponent(0.2)
        let indicatorGlass = UIVisualEffectView(effect: glass)
        indicatorGlass.cornerConfiguration = .capsule()
        indicatorGlass.translatesAutoresizingMaskIntoConstraints = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.hidesForSinglePage = false
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.4)
        pageControl.addAction(UIAction { [weak self] _ in
            self?.showPage(at: self?.pageControl.currentPage ?? 0)
        }, for: .valueChanged)
        indicatorGlass.contentView.addSubview(pageControl)

        listButton.configuration?.image = UIImage(systemSymbol: .listBullet)
        listButton.accessibilityLabel = String.ForecastUI.forecastPagerList
        listButton.translatesAutoresizingMaskIntoConstraints = false
        listButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .primaryActionTriggered)

        view.addSubview(indicatorGlass)
        view.addSubview(listButton)

        let barHeight: CGFloat = 48
        NSLayoutConstraint.activate([
            indicatorGlass.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicatorGlass.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            indicatorGlass.heightAnchor.constraint(equalToConstant: barHeight),
            indicatorGlass.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 72),
            pageControl.leadingAnchor.constraint(equalTo: indicatorGlass.contentView.leadingAnchor, constant: 8),
            pageControl.trailingAnchor.constraint(equalTo: indicatorGlass.contentView.trailingAnchor, constant: -8),
            pageControl.centerYAnchor.constraint(equalTo: indicatorGlass.contentView.centerYAnchor),

            listButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            listButton.centerYAnchor.constraint(equalTo: indicatorGlass.centerYAnchor),
            listButton.widthAnchor.constraint(equalToConstant: barHeight),
            listButton.heightAnchor.constraint(equalToConstant: barHeight),
        ])
    }

    // MARK: Pages

    private func page(for placeId: String) -> any PlaceForecastScreen {
        if let existing = pages[placeId] {
            return existing
        }

        let page = PlaceForecastScreenBuilder(placeId: placeId).build()
        pages[placeId] = page
        return page
    }

    /// Keeps the pager in step with the places list: pages for removed
    /// places are dropped, and the visible page stays put if it still exists.
    private func placesChanged(_ placeIds: [String]) {
        pages = pages.filter { placeIds.contains($0.key) }
        pageControl.numberOfPages = placeIds.count
        pageControl.isHidden = placeIds.isEmpty

        // The current location, always first, gets an arrow for its dot.
        if model.firstIsCurrentLocation {
            pageControl.setIndicatorImage(UIImage(systemSymbol: .locationFill), forPage: 0)
        } else if !placeIds.isEmpty {
            pageControl.setIndicatorImage(nil, forPage: 0)
        }

        guard !placeIds.isEmpty else {
            // Nothing left to page through.
            navigationController?.popViewController(animated: true)
            return
        }

        let visibleId = (pageViewController.viewControllers?.first as? any PlaceForecastScreen)?.placeId
        let targetId = visibleId.flatMap { placeIds.contains($0) ? $0 : nil } ?? model.initialPlaceId(in: placeIds)
        if visibleId != targetId {
            pageViewController.setViewControllers([page(for: targetId)], direction: .forward, animated: false)
        }
        pageControl.currentPage = placeIds.firstIndex(of: targetId) ?? 0
    }

    private func showPage(at index: Int) {
        let placeIds = model.placeIds
        guard placeIds.indices.contains(index) else {
            return
        }

        let currentIndex = currentPlaceId.flatMap { placeIds.firstIndex(of: $0) } ?? 0
        pageViewController.setViewControllers(
            [page(for: placeIds[index])],
            direction: index >= currentIndex ? .forward : .reverse,
            animated: true,
        )
    }

    private var currentPlaceId: String? {
        (pageViewController.viewControllers?.first as? any PlaceForecastScreen)?.placeId
    }
}

extension PlacePagerScreenImpl: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController,
    ) -> UIViewController? {
        neighbor(of: viewController, offset: -1)
    }

    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController,
    ) -> UIViewController? {
        neighbor(of: viewController, offset: 1)
    }

    public func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool,
    ) {
        guard completed, let currentPlaceId else {
            return
        }

        pageControl.currentPage = model.placeIds.firstIndex(of: currentPlaceId) ?? 0
    }

    private func neighbor(of viewController: UIViewController, offset: Int) -> UIViewController? {
        let placeIds = model.placeIds
        guard
            let placeId = (viewController as? any PlaceForecastScreen)?.placeId,
            let index = placeIds.firstIndex(of: placeId),
            placeIds.indices.contains(index + offset)
        else {
            return nil
        }

        return page(for: placeIds[index + offset])
    }
}

/// The pager's state: which places, in what order, and where to start.
@Observable @MainActor
final class PlacePagerScreenModel {
    weak var viewController: UIViewController?

    private(set) var placeIds: [String] = []
    private(set) var firstIsCurrentLocation = false
    private let requestedInitialPlaceId: String?

    @ObservationIgnored private let placesManager: PlacesManager = Inject()

    init(initialPlaceId: String?) {
        self.requestedInitialPlaceId = initialPlaceId

        // Start from the list as it is now, so the pager's first layout has
        // pages; an empty first value would make it pop straight back.
        let places = placesManager.places.value
        self.placeIds = places.map(\.id)
        self.firstIsCurrentLocation = places.first?.isCurrentLocation ?? false

        Task.observe(bindTo: self) { [placesManager] in
            placesManager.places.value
        } perform: { [weak self] places in
            self?.placeIds = places.map(\.id)
            self?.firstIsCurrentLocation = places.first?.isCurrentLocation ?? false
        }
    }

    /// The requested page if it exists, otherwise the first.
    func initialPlaceId(in placeIds: [String]) -> String {
        requestedInitialPlaceId.flatMap { placeIds.contains($0) ? $0 : nil } ?? placeIds[0]
    }
}
