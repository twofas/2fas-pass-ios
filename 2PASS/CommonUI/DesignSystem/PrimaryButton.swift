// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct PrimaryButton: View {
    private let minHeight: Double = 50
    private let cornerSize = 12
    
    let title: String
    let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .foregroundStyle(Color.white)
                .background {
                    RoundedRectangle(cornerSize: CGSize(width: cornerSize, height: cornerSize))
                }
        }
    }
}
