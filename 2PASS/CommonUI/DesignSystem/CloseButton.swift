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
            if #available(iOS 26, *) {
                Image(systemName: "xmark")
            } else {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.neutral600, colorScheme == .dark ? .neutral300 : .neutral100)
            }
        }
        .accessibilityLabel(Text("Close button"))
        .modify {
            if #available(iOS 26, *) {
                $0.buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            } else {
                $0.buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    CloseButton(closeAction: {})
}
