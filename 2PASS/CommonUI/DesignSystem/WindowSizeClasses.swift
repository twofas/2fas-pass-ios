// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit

/// Size classes of the app's window — unlike the view's `horizontalSizeClass`, not overridden
/// to `.compact` inside sheet presentations. Call `startObserving(_:)` where the window is created.
@Observable
public final class WindowSizeClasses {

    public static let shared = WindowSizeClasses()

    public private(set) var horizontal: UserInterfaceSizeClass?
    public private(set) var vertical: UserInterfaceSizeClass?

    @ObservationIgnored
    private weak var observedWindow: UIWindow?

    @ObservationIgnored
    private var traitChangeRegistration: (any UITraitChangeRegistration)?

    @MainActor
    public func startObserving(_ window: UIWindow) {
        if let observedWindow, let traitChangeRegistration {
            observedWindow.unregisterForTraitChanges(traitChangeRegistration)
        }

        observedWindow = window
        traitChangeRegistration = window.registerForTraitChanges(
            [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
        ) { [weak self] (window: UIWindow, _) in
            self?.update(from: window.traitCollection)
        }
        update(from: window.traitCollection)
    }

    private func update(from traits: UITraitCollection) {
        horizontal = UserInterfaceSizeClass(traits.horizontalSizeClass)
        vertical = UserInterfaceSizeClass(traits.verticalSizeClass)
    }
}

extension EnvironmentValues {

    /// The app window's size classes; both are `nil` until observation starts (previews, extensions).
    public var windowSizeClasses: WindowSizeClasses {
        get { self[WindowSizeClassesKey.self] }
        set { self[WindowSizeClassesKey.self] = newValue }
    }
}

private struct WindowSizeClassesKey: EnvironmentKey {
    static let defaultValue = WindowSizeClasses.shared
}
