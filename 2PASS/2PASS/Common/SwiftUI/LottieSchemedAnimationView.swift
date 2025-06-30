// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Lottie

struct LottieSchemedAnimationView<Content>: View where Content: View {
    
    let baseNamed: String
    @ViewBuilder var content: (LottieView<EmptyView>) -> Content
    @Environment(\.colorScheme) private var colorScheme

    init(baseNamed: String, @ViewBuilder content: @escaping (LottieView<EmptyView>) -> Content) {
        self.baseNamed = baseNamed
        self.content = content
    }
    
    var body: some View {
        content(
            LottieView(animation: .named(animationName))
        )
    }
    
    private var animationName: String {
        colorScheme == .light ? "\(baseNamed)-light" : "\(baseNamed)-dark"
    }
}
