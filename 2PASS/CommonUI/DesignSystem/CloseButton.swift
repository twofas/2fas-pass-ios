// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct CloseButton: View {
    
    let closeAction: Callback
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    public init(closeAction: @escaping Callback) {
        self.closeAction = closeAction
    }
    
    public var body: some View {
        Button {
            closeAction()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundStyle(.neutral600, colorScheme == .dark ? .neutral300 : .neutral100)
        }
        .accessibilityLabel(Text("Close button"))
        .buttonStyle(.plain)
    }
}

#Preview {
    CloseButton(closeAction: {})
}
