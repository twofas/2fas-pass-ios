// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct GroupedForm<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                content()
            }
            .padding(.vertical, Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
    }
}

public struct GroupedSection<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                Group(subviews: content()) { subviews in
                    VStack(spacing: 0) {
                        ForEach(Array(subviews.enumerated()), id: \.offset) { index, child in
                            GroupedRow {
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
                _VariadicView.Tree(GroupedRowLayout()) {
                    content()
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .padding(.horizontal, Spacing.l)
    }

    private var cornerRadius: CGFloat {
        if #available(iOS 26, *) {
            return 24
        } else {
            return 12
        }
    }
}

public struct GroupedRowHighlightButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .groupedRowBackground(configuration.isPressed ? Color.neutral100 : nil)
    }
}

public extension ButtonStyle where Self == GroupedRowHighlightButtonStyle {
    static var groupedRowHighlight: Self {
        .init()
    }
}

public extension View {

    func groupedRowBackground<V>(_ view: V?) -> some View where V: View {
        preference(key: GroupedRowBackgroundKey.self, value: view.map { AnyView($0) })
    }

    func groupedRowInsets(_ insets: EdgeInsets) -> some View {
        preference(key: GroupedRowInsetsKey.self, value: insets)
    }
}

private struct GroupedRow<Content: View>: View {
    @State private var customInsets: EdgeInsets?
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let insets = customInsets ?? defaultInsets
        content
            .padding(.top, insets.top)
            .padding(.leading, insets.leading)
            .padding(.bottom, insets.bottom)
            .padding(.trailing, insets.trailing)
            .backgroundPreferenceValue(GroupedRowBackgroundKey.self) { view in
                view
            }
            .onPreferenceChange(GroupedRowInsetsKey.self) { value in
                customInsets = value
            }
    }

    private var defaultInsets: EdgeInsets {
        EdgeInsets(top: Spacing.l, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l)
    }
}

private struct GroupedRowBackgroundKey: PreferenceKey {
    static var defaultValue: AnyView? = nil

    static func reduce(value: inout AnyView?, nextValue: () -> AnyView?) {
        value = nextValue()
    }
}

private struct GroupedRowInsetsKey: PreferenceKey {
    static let defaultValue: EdgeInsets? = nil
    static func reduce(value: inout EdgeInsets?, nextValue: () -> EdgeInsets?) {
        value = nextValue() ?? value
    }
}

private struct GroupedRowLayout: _VariadicView_UnaryViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                GroupedRow {
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
