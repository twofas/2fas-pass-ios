// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let cornerRadius: CGFloat = 24
    static let defaultInsets: EdgeInsets = .init(top: Spacing.l, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l)
}

struct ShareLinkSection<Content: View>: View {

    @Environment(\.colorScheme) private var colorScheme

    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dividedContent
        }
        .background(colorScheme == .dark ? Color.neutral50 : Color.base0)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }
        
    @ViewBuilder
    private var dividedContent: some View {
        if #available(iOS 18.0, *) {
            Group(subviews: content()) { subviews in
                VStack(spacing: 0) {
                    ForEach(Array(subviews.enumerated()), id: \.offset) { index, child in
                        ShareLinkRow {
                            child
                        }
                        
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
}

private struct ShareLinkRow<Content: View>: View {
    
    @State private var customInsets: EdgeInsets?
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let insets = customInsets ?? Constants.defaultInsets
        content()
            .padding(.top, insets.top)
            .padding(.leading, insets.leading)
            .padding(.bottom, insets.bottom)
            .padding(.trailing, insets.trailing)
            .onPreferenceChange(ShareLinkRowInsetsKey.self) { value in
                customInsets = value
            }
    }
}

extension View {
    func shareLinkRowInsets(_ insets: EdgeInsets) -> some View {
        preference(key: ShareLinkRowInsetsKey.self, value: insets)
    }
}

private struct ShareLinkRowInsetsKey: PreferenceKey {
    static let defaultValue: EdgeInsets? = nil
    static func reduce(value: inout EdgeInsets?, nextValue: () -> EdgeInsets?) {
        value = nextValue() ?? value
    }
}
