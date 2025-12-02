// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct LockButton: View {
    
    let text: Text
    let action: () -> Void
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: Spacing.m) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(colorScheme == .dark ? .neutral400 : .neutral200)
                
                text
            }
        }
        .contentShape(Rectangle())
        .padding(.bottom, Spacing.xs)
        .buttonStyle(.borderless)
    }
}
