// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

/// How a screen enters the flow stack: the system transition or the slide the onboarding steps use.
public enum FlowPushKind: Sendable {
    case system
    case slide
}

/// The flow stack a hosted screen can push onto; absent in a sheet or a `NavigationStack` of its own.
@MainActor
public struct FlowNavigationAction {

    private let pushAction: (AnyView, FlowPushKind, @escaping @MainActor () -> Void) -> Void
    private let popAction: () -> Void

    public init(
        push: @escaping (AnyView, FlowPushKind, @escaping @MainActor () -> Void) -> Void,
        pop: @escaping () -> Void
    ) {
        self.pushAction = push
        self.popAction = pop
    }

    /// `onPop` runs once when the pushed screen leaves the stack by any route (system Back, swipe, programmatic pop).
    public func push(_ view: AnyView, kind: FlowPushKind, onPop: @escaping @MainActor () -> Void) {
        pushAction(view, kind, onPop)
    }

    /// Pops back to the screen this action was handed to, removing everything above it.
    public func pop() {
        popAction()
    }
}

private struct FlowNavigationEnvironmentKey: EnvironmentKey {
    static var defaultValue: FlowNavigationAction? {
        nil
    }
}

extension EnvironmentValues {

    public var flowNavigation: FlowNavigationAction? {
        get {
            self[FlowNavigationEnvironmentKey.self]
        } set {
            self[FlowNavigationEnvironmentKey.self] = newValue
        }
    }
}

/// A trailing bar item a hosted screen declares; equal by image alone, so a fresh closure is no change.
public struct FlowBarItem: Equatable {
    public let systemImage: String
    public let action: @MainActor () -> Void

    public static func == (lhs: FlowBarItem, rhs: FlowBarItem) -> Bool {
        lhs.systemImage == rhs.systemImage
    }
}

struct FlowBarTrailingItemPreferenceKey: PreferenceKey {
    static var defaultValue: FlowBarItem? {
        nil
    }

    static func reduce(value: inout FlowBarItem?, nextValue: () -> FlowBarItem?) {
        value = nextValue() ?? value
    }
}

extension View {

    /// Declares a trailing bar item the hosting flow stack places as a `UIBarButtonItem`.
    public func flowBarTrailingItem(systemImage: String, action: @escaping @MainActor () -> Void) -> some View {
        preference(key: FlowBarTrailingItemPreferenceKey.self, value: FlowBarItem(systemImage: systemImage, action: action))
    }
}
