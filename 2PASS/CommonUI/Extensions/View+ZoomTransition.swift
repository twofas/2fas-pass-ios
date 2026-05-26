// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension View {

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
        if let namespace {
            content.navigationTransition(.zoom(sourceID: idResolver(), in: namespace))
        } else {
            content
        }
    }
}
