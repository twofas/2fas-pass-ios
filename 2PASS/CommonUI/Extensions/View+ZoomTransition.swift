// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension View {

    /// Anchors a matched-zoom *source* when `namespace` is non-nil and the platform
    /// supports iOS 26+ navigation transitions; passes through unchanged otherwise.
    ///
    /// The id is taken via `@autoclosure`, so both literal call sites
    /// (`id: "foo"`) and `@Observable` expressions (`id: presenter.someProp`) use
    /// the same overload — the expression is wrapped into a closure and evaluated
    /// inside the `ViewModifier`'s body, where SwiftUI's observation tracking is
    /// active. Static-id callers pay one `ViewModifier` indirection; reactive
    /// callers get body re-fires on property change without any extra wiring.
    ///
    /// On pre-iOS-26 (or non-iOS platforms) the modifier is skipped entirely —
    /// the autoclosure expression is constructed (one closure capture) but never
    /// invoked.
    @ViewBuilder
    func matchedZoomSource(
        id: @autoclosure @escaping @MainActor () -> String,
        in namespace: Namespace.ID?
    ) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            modifier(MatchedZoomSourceModifier(idResolver: id, namespace: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Anchors a matched-zoom *destination* when `namespace` is non-nil and the
    /// platform supports iOS 26+ navigation transitions; passes through unchanged
    /// otherwise. See `matchedZoomSource(id:in:)` for autoclosure semantics — the
    /// destination overload is most useful with reactive ids (e.g. flipping the
    /// zoom target mid-sheet-dismiss based on `@Observable` state).
    @ViewBuilder
    func matchedZoomDestination(
        id: @autoclosure @escaping @MainActor () -> String,
        in namespace: Namespace.ID?
    ) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            modifier(MatchedZoomDestinationModifier(idResolver: id, namespace: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

@available(iOS 26.0, *)
private struct MatchedZoomSourceModifier: ViewModifier {

    let idResolver: @MainActor () -> String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: idResolver(), in: namespace)
        } else {
            content
        }
    }
}

@available(iOS 26.0, *)
private struct MatchedZoomDestinationModifier: ViewModifier {

    let idResolver: @MainActor () -> String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        // `idResolver()` runs inside this body — when the autoclosure expression
        // reads an `@Observable` property, the dependency is registered here, and
        // a change re-fires the body so the underlying transition picks up the
        // new source id in place (no sheet teardown).
        if let namespace {
            content.navigationTransition(.zoom(sourceID: idResolver(), in: namespace))
        } else {
            content
        }
    }
}
