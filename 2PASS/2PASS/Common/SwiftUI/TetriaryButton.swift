// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct TetriaryButton: View {
    @Environment(\.isEnabled) private var isEnabled
    private let minHeight: Double = 25
    private let cornerSize = 8
    
    let title: String
    let icon: Image?
    let action: () -> Void

    init(title: String, icon: Image? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            text
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .foregroundStyle(Color.white)
                .background {
                    RoundedRectangle(cornerSize: CGSize(width: cornerSize, height: cornerSize))
                }
        }
    }
    
    @ViewBuilder
    var text: some View {
        Group {
            if let icon {
                Text("\(icon) \(title)" as String)
            } else {
                Text(title)
            }
        }
        .font(.caption2)
        .fontWeight(.medium)
    }
}
