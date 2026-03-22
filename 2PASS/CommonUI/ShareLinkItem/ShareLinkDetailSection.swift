// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ShareLinkDetailSection<Content: View>: View {

    @Environment(\.colorScheme) private var colorScheme

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if #available(iOS 18.0, *) {
                Group(subviews: content()) { subviews in
                    VStack(spacing: 0) {
                        ForEach(Array(subviews.enumerated()), id: \.offset) { index, child in
                            child
                                .padding(.vertical, Spacing.l)
                                .padding(.horizontal, Spacing.l)

                            if index < subviews.count - 1 {
                                Divider()
                                    .padding(.horizontal, Spacing.l)
                            }
                        }
                    }
                }
            } else {
                content()
                    .padding(.vertical, Spacing.m)
                    .padding(.horizontal, Spacing.l)
            }
        }
        .background(colorScheme == .dark ? Color.neutral50 : Color.base0)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
    }
}
