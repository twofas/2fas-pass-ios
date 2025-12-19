// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ItemDetailForm<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                content()
            }
            .padding(.vertical, Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct ItemDetailSection<Content: View, Footer: View>: View {
    let content: () -> Content
    let footer: (() -> Footer)?

    init(
        @ViewBuilder content: @escaping () -> Content
    ) where Footer == EmptyView {
        self.content = content
        self.footer = nil
    }

    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.content = content
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if #available(iOS 18.0, *) {
                    Group(subviews: content()) { subviews in
                        VStack(spacing: 0) {
                            ForEach(Array(subviews.enumerated()), id: \.offset) { index, child in
                                ItemDetailFormRow {
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
                    _VariadicView.Tree(ItemDetailFormRowLayout()) {
                        content()
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .padding(.horizontal)

            if let footer = footer {
                footer()
                    .font(.footnote)
                    .foregroundColor(Color(.secondaryLabel))
                    .padding(.horizontal, Spacing.xll3)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var cornerRadius: CGFloat {
        if #available(iOS 26, *) {
            return 24
        } else {
            return 12
        }
    }
}

extension View {
    
    func itemDetailFormRowBackground<V>(_ view: V?) -> some View where V : View {
        preference(key: ItemDetailFormRowBackgroundKey.self, value: view.map { AnyView($0) })
    }
}

private struct ItemDetailFormRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, Spacing.l)
            .padding(.horizontal, Spacing.l)
            .backgroundPreferenceValue(ItemDetailFormRowBackgroundKey.self) { view in
                view
            }
    }
}

private struct ItemDetailFormRowBackgroundKey: PreferenceKey {
    static var defaultValue: AnyView? = nil

    static func reduce(value: inout AnyView?, nextValue: () -> AnyView?) {
        value = nextValue()
    }
}

private struct ItemDetailFormRowLayout: _VariadicView_UnaryViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                ItemDetailFormRow {
                    child
                }
                
                if index < children.count - 1 {
                    Divider()
                        .padding(.horizontal, Spacing.l)
                }
            }
        }
    }
}
