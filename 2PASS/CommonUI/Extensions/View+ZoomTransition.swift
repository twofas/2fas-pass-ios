// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension View {
    @ViewBuilder
    func matchedZoomSource(id: String, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func matchedZoomDestination(id: String, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Optional-namespace overload. Applies the zoom source when `namespace` is non-nil,
    /// passes through unchanged otherwise. Useful where the namespace is held as an
    /// optional (e.g. on Router structs that may be constructed without one).
    @ViewBuilder
    func matchedZoomSource(id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedZoomSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Optional-namespace overload. Applies the zoom destination when `namespace` is
    /// non-nil, passes through unchanged otherwise. Useful where the namespace is held
    /// as an optional (e.g. on Router structs that may be constructed without one).
    @ViewBuilder
    func matchedZoomDestination(id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedZoomDestination(id: id, in: namespace)
        } else {
            self
        }
    }
}
