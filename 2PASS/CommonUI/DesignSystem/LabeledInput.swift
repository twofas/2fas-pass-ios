// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct LabeledInput<Content: View>: View {
    private let label: Text
    private let minWidth: CGFloat?
    
    @Binding
    private var fieldWidth: CGFloat?
    
    @ViewBuilder
    private let content: () -> Content
    
    public init(
        label: LocalizedStringKey,
        fieldWidth: Binding<CGFloat?>,
        minWidth: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = Text(label)
        self.minWidth = minWidth
        _fieldWidth = fieldWidth
        self.content = content
    }
    
    @_disfavoredOverload
    public init(
        label: String,
        fieldWidth: Binding<CGFloat?>,
        minWidth: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = Text(label)
        self.minWidth = minWidth
        _fieldWidth = fieldWidth
        self.content = content
    }
    
    public var body: some View {
        HStack {
            label
                .observeWidth { updateWidth($0) }
                .frame(width: fieldWidth, alignment: .leading)
            content()
        }
    }
    
    private func updateWidth(_ newValue: CGFloat) {
        if let fieldWidth {
            if newValue > fieldWidth {
                self.fieldWidth = max(minWidth ?? 0, newValue)
            }
        } else {
            self.fieldWidth = max(minWidth ?? 0, newValue)
        }
    }
}
