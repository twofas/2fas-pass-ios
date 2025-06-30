// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension View {
    
    public func readableContentMargins() -> some View {
        containerRelativeFrame([.horizontal]) { length, axis in
            guard axis == .horizontal else { return length }
            return min(600, length)
        }
    }
    
    public func scrollReadableContentMargins() -> some View {
        modifier(ScrollReadableContentMarginsViewModifier())
    }
}

private struct ScrollReadableContentMarginsViewModifier: ViewModifier {
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            GeometryReader { proxy in
                content
                    .contentMargins(.horizontal, max(0, (proxy.size.width - 600) / 2), for: .scrollContent)
            }
        } else {
            content
        }
    }
}
