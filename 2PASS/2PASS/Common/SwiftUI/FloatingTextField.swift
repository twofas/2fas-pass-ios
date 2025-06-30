// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let focusedPlaceholderScale: CGFloat = 0.7
    static let focusedPlaceholderVerticalOffset: CGFloat = -10
}

struct FloatingField<Label>: View where Label: View {
    
    let placeholder: Text
    let isEmpty: Bool

    @ViewBuilder var label: () -> Label
    
    @FocusState var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .leading) {
            placeholder
                .foregroundStyle(.neutral500)
                .scaleEffect(isFocused || isEmpty == false ? Constants.focusedPlaceholderScale : 1, anchor: .topLeading)
                .offset(y: isFocused || isEmpty == false ? Constants.focusedPlaceholderVerticalOffset : 0)
                .animation(.default, value: isFocused)
            
            label()
                .focused($isFocused)
                .padding(.top, 20)
        }
    }
}

#Preview {
    FloatingField(placeholder: Text("Placeholder"), isEmpty: false) {
        TextField("", text: .constant("Test"))
    }
    .padding()
}
