// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct IconInput<Content: View>: View {
    private let text: Text
    
    @Binding
    private var fieldWidth: CGFloat?
    
    @ViewBuilder
    private let content: () -> Content
    
    init(
        text: Text,
        fieldWidth: Binding<CGFloat?>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.text = text
        _fieldWidth = fieldWidth
        self.content = content
    }
    
    var body: some View {
        LabeledContent {
            content()
        } label: {
            text
                .observeWidth { updateWidth($0) }
                .frame(width: fieldWidth, alignment: .leading)
        }
    }
    
    private func updateWidth(_ newValue: CGFloat) {
        if let fieldWidth {
            if newValue > fieldWidth {
                self.fieldWidth = newValue
            }
        } else {
            self.fieldWidth = newValue
        }
    }
}
