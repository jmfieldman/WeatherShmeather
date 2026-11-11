//
//  App.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// A class that represents the application's build and runtime environment configuration.
///
/// This class provides information about the current build configuration (debug or release)
/// and runtime environment (simulator, TestFlight, or App Store) that the application is running in.
public final class App: Sendable {
    /// The build configuration of the application.
    ///
    /// This property indicates whether the application is running in debug or release mode.
    /// It can be explicitly set during initialization or automatically detected based on
    /// the compilation settings.
    public let buildConfiguration: BuildConfiguration

    /// The runtime environment of the application.
    ///
    /// This property indicates where the application is currently running, such as
    /// on a simulator, TestFlight, or in the App Store. It can be explicitly set
    /// during initialization or automatically detected based on the runtime environment.
    public let runEnvironment: RunEnvironment

    /// The bundle identifier of the application.
    ///
    /// This property contains the application's bundle identifier, which is used
    /// to uniquely identify the app in the system.
    public let bundleId: String

    /// The bundle name of the application.
    ///
    /// This property contains the application's bundle name, which is typically
    /// the name of the app's main bundle.
    public let bundleName: String

    /// The bundle display name of the application.
    ///
    /// This property contains the application's display name as configured in
    /// the app's Info.plist file.
    public let bundleDisplayName: String

    /// The version of the app, reflecting major.minor.patch.build.
    public let version: String

    /// The semver-style marketing version of the app, e.g. `1.2.3`. Sourced
    /// from `CFBundleShortVersionString`. Distinct from `version` (which
    /// carries `CFBundleVersion`, the build number in this codebase's
    /// Info.plist) — analytics super-properties require the semver form so
    /// server-side schema regex validation accepts the batch.
    public let appVersion: String

    /// The build identifier of the current binary. Sourced from
    /// `CFBundleVersion`. Paired with `appVersion` to disambiguate TestFlight
    /// builds that share the same marketing version.
    public let appBuild: String

    /// The application ID prefix of the application.
    ///
    /// This property contains the application's ID prefix, which is used for
    /// identifying the app in Apple's ecosystem. This is typically a 10-character
    /// string.
    public let appIdPrefix: String

    /// Initializes a new instance of `App` with the specified build and run environments.
    ///
    /// - Parameters:
    ///   - buildConfiguration: The build configuration to use. If `nil`, the configuration
    ///     will be automatically detected based on the compilation settings.
    ///   - runEnvironment: The runtime environment to use. If `nil`, the environment
    ///     will be automatically detected based on the runtime context.
    public init(
        buildConfiguration: BuildConfiguration? = nil,
        runEnvironment: RunEnvironment? = nil,
        bundleId: String? = nil,
        bundleName: String? = nil,
        bundleDisplayName: String? = nil,
        version: String? = nil,
        appVersion: String? = nil,
        appBuild: String? = nil,
        appIdPrefix: String? = nil,
    ) {
        self.buildConfiguration = buildConfiguration ?? .detected
        self.runEnvironment = runEnvironment ?? .detected
        self.bundleId = bundleId ?? Self.detectedBundleId
        self.bundleName = bundleName ?? Self.detectedBundleName
        self.bundleDisplayName = bundleDisplayName ?? Self.detectedBundleDisplayName
        self.version = version ?? Self.detectedVersion
        self.appVersion = appVersion ?? Self.detectedAppVersion
        self.appBuild = appBuild ?? Self.detectedAppBuild
        self.appIdPrefix = appIdPrefix ?? Self.detectedAppIdPrefix
    }
}

private extension App {
    /// The bundle identifier of the application, automatically detected from the main bundle.
    static var detectedBundleId: String {
        Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
    }

    /// The bundle name of the application, automatically detected from the main bundle.
    static var detectedBundleName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
    }

    /// The bundle display name of the application, automatically detected from the main bundle.
    static var detectedBundleDisplayName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? ""
    }

    /// The detected version of the app in major.minor.patch.build
    static var detectedVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    /// The detected marketing version, e.g. `1.2.3`, from
    /// `CFBundleShortVersionString`.
    static var detectedAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// The detected build identifier, from `CFBundleVersion`.
    static var detectedAppBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    /// The application ID prefix, automatically detected from the main bundle.
    static var detectedAppIdPrefix: String {
        Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String ?? ""
    }
}

public extension App {
    /// An enumeration that defines the build configurations for the application.
    ///
    /// This enum represents the different build configurations that an application
    /// can be compiled with, such as debug or release.
    enum BuildConfiguration: Sendable {
        /// Debug build configuration.
        ///
        /// This configuration is typically used during development and includes
        /// additional debugging information and features.
        case debug

        /// Release build configuration.
        ///
        /// This configuration is used for production builds and is optimized
        /// for performance and size.
        case release

        /// Automatically detected build configuration.
        ///
        /// This property returns the build configuration based on the compilation
        /// settings. It checks for the `DEBUG` flag to determine if it's a debug build.
        static var detected: BuildConfiguration {
            #if DEBUG
            .debug
            #else
            .release
            #endif
        }
    }

    /// An enumeration that defines the runtime environments for the application.
    ///
    /// This enum represents the different environments where the application can run,
    /// such as simulator, TestFlight, or App Store.
    enum RunEnvironment: Sendable {
        /// Simulator runtime environment.
        ///
        /// This configuration indicates that the application is running in the iOS simulator.
        case simulator

        /// AdHoc runtime environment.
        ///
        /// This configuration indicates that the application is running through an AdHoc install.
        case adHoc

        /// TestFlight runtime environment.
        ///
        /// This configuration indicates that the application is running through TestFlight.
        case testFlight

        /// App Store runtime environment.
        ///
        /// This configuration indicates that the application is running from the App Store.
        case appStore

        /// Automatically detected runtime environment.
        ///
        /// This property returns the runtime environment based on the current execution context.
        /// It checks for the simulator environment and determines if the app is running
        /// through TestFlight or from the App Store.
        static var detected: RunEnvironment {
            #if targetEnvironment(simulator)
            return .simulator
            #else
            if Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil {
                return .adHoc
            }
            let receiptURL = (Bundle.main as NSObject).value(forKey: "appStoreReceiptURL") as? URL
            return receiptURL?.lastPathComponent == "sandboxReceipt" ? .testFlight : .appStore
            #endif
        }
    }
}
