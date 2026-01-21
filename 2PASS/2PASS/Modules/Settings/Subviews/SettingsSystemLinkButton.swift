// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct SettingsSystemLinkButton: View {
    
    let description: Text
    let action: Callback
    
    var body: some View {
        VStack(spacing: Spacing.m) {
            description
                .lineSpacing(2)
                .font(.caption)
                .foregroundStyle(.neutral600)
            
            Button(.commonOpenSystemSettings, action: action)
                .buttonStyle(.filled)
                .controlSize(.large)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
    }
}
