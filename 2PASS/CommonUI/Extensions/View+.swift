// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension View {
    @ViewBuilder func isHidden(_ hidden: Bool, remove: Bool = false) -> some View {
        if hidden {
            if !remove {
                self.hidden()
            }
        } else {
            self
        }
    }
    
    @ViewBuilder func `if`<Content: View>(_ conditional: Bool, content: (Self) -> Content) -> some View {
         if conditional {
            AnyView(content(self))
         } else {
            AnyView(self)
         }
     }
    
    @ViewBuilder func ifElse<Content: View>(
        _ conditional: Bool,
        @ViewBuilder contentIf: (Self) -> Content,
        @ViewBuilder contentElse: (Self) -> Content
    ) -> some View {
         if conditional {
            AnyView(contentIf(self))
         } else {
            AnyView(contentElse(self))
         }
     }
    
    @inlinable
    func modify<T: View>(@ViewBuilder modifier: (Self) -> T) -> T {
        modifier(self)
    }
    
    func observeSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: SizeReaderPreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(SizeReaderPreferenceKey.self, perform: onChange)
    }
    
    func observeHeight(onChange: @escaping (CGFloat) -> Void) -> some View {
        observeSize { size in
            onChange(size.height)
        }
    }
    
    func observeWidth(onChange: @escaping (CGFloat) -> Void) -> some View {
        observeSize { size in
            onChange(size.width)
        }
    }
}

private struct SizeReaderPreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
