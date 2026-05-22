// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension View {

    /// Anchors a matched-zoom source when `namespace` is non-nil on iOS 26+. The id is
    /// `@autoclosure` so reactive expressions (`id: presenter.someProp`) re-evaluate
    /// inside the modifier's body and propagate observation changes without extra wiring.
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

    /// Destination counterpart to `matchedZoomSource(id:in:)`. Useful with reactive ids
    /// — e.g. flipping the zoom target mid-sheet-dismiss based on `@Observable` state.
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
        // `idResolver()` runs here so an `@Observable`-reading autoclosure registers its
        // dependency on this body — a change re-fires it and the transition picks up the
        // new source id in place.
        if let namespace {
            content.navigationTransition(.zoom(sourceID: idResolver(), in: namespace))
        } else {
            content
        }
    }
}
