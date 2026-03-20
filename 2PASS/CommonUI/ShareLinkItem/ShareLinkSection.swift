// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ShareLinkSection<Content: View>: View {

    @Environment(\.colorScheme) private var colorScheme

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.vertical, Spacing.m)
        }
        .background(colorScheme == .dark ? Color.neutral50 : Color.base0)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
