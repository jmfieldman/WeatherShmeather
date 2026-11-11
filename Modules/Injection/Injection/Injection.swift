//
//  Injection.swift
//  Copyright © 2026 WeatherShmeather.
//

import DeviceLocationManager
import DeviceLocationManagerImpl
@_exported import Inject
import NetworkManager
import NetworkManagerImpl
import PlacesManager
import PlacesManagerImpl
import PlacesUI
import PlacesUIImpl
import PreferencesManager
import PreferencesManagerImpl
import RootUI
import RootUIImpl
import SessionCoordinator
import SessionCoordinatorImpl
import SessionManager
import SessionManagerImpl
import SettingsUI
import SettingsUIImpl
import SignInUI
import SignInUIImpl
import SlateManager
import SlateManagerImpl

@MainActor
public extension InjectionManager {
    static func registerInjections() {
        InjectionManager.unsafeRegister(DeviceLocationManager.self) { DeviceLocationManagerImpl() }
        InjectionManager.unsafeRegister(NetworkManager.self) { NetworkManagerImpl() }
        InjectionManager.unsafeRegister(PlacesManager.self) { PlacesManagerImpl() }
        InjectionManager.unsafeRegister(PreferencesManager.self) { PreferencesManagerImpl() }
        InjectionManager.unsafeRegister(SessionManager.self) { SessionManagerImpl() }
        InjectionManager.unsafeRegister(SlateManager.self) { SlateManagerImpl() }
    }

    static func activateInjections() {
        _ = Inject(DeviceLocationManager.self)
        _ = Inject(NetworkManager.self)
        _ = Inject(PlacesManager.self)
        _ = Inject(PreferencesManager.self)
        _ = Inject(SessionManager.self)
        _ = Inject(SlateManager.self)
    }
}

@MainActor
public extension BuilderManager {
    static func registerBuilders() {
        BuilderManager.unsafeRegister(PlacesListScreenBuilder.self) { PlacesListScreenImpl(builder: $0 as! PlacesListScreenBuilder) }
        BuilderManager.unsafeRegister(RootViewControllerBuilder.self) { RootViewControllerImpl(builder: $0 as! RootViewControllerBuilder) }
        BuilderManager.unsafeRegister(SessionCoordinatorBuilder.self) { SessionCoordinatorImpl(builder: $0 as! SessionCoordinatorBuilder) }
        BuilderManager.unsafeRegister(SignInScreenBuilder.self) { SignInScreenImpl(builder: $0 as! SignInScreenBuilder) }
        BuilderManager.unsafeRegister(UnitsScreenBuilder.self) { UnitsScreenImpl(builder: $0 as! UnitsScreenBuilder) }
    }
}
