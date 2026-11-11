//
//  Injection.swift
//  Copyright © 2026 WeatherShmeather.
//

@_exported import Inject
import RootTabUI
import RootTabUIImpl

@MainActor
public extension InjectionManager {
    static func registerInjections() {}

    static func activateInjections() {}
}

@MainActor
public extension BuilderManager {
    static func registerBuilders() {
        BuilderManager.unsafeRegister(RootTabViewControllerBuilder.self) { RootTabViewControllerImpl(builder: $0 as! RootTabViewControllerBuilder) }
    }
}
