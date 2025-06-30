// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct SettingsHeaderView<Icon, Title, Description>: View where Icon: View, Title: View, Description: View {

    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let title: () -> Title
    @ViewBuilder let description: () -> Description
    
    @State private var navigationBarTitleHidden = true
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            
            VStack(spacing: Spacing.s) {
                icon()
                    .controlSize(.large)
                    .padding(.bottom, Spacing.s)
                
                title()
                    .font(.title2Emphasized)
                    .foregroundStyle(.neutral950)
                    .onAppear {
                        navigationBarTitleHidden = true
                    }
                    .onDisappear {
                        navigationBarTitleHidden = false
                    }
                
                description()
                    .foregroundStyle(.neutral950)
                    .font(.footnote)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xll2)
        .padding(.horizontal, Spacing.l)
        .multilineTextAlignment(.center)
        .settingsFormNavigationBarTitleHidden(navigationBarTitleHidden)
    }
}

extension SettingsHeaderView where Title == Text, Icon == SettingsIconView, Description == Text {
    
    init(icon: SettingsIcon, title: Text, description: Text) {
        self.icon = { SettingsIconView(icon: icon) }
        self.title = { title }
        self.description = { description }
    }
}

#Preview {
    Form {
        SettingsHeaderView(
            icon: .sync,
            title: Text("Vault Sync"),
            description: Text("Securely sync your 2FAS Pass Vault with iCloud or WebDAV to protect your data if this device gets lost or damaged.")
        )
    }
}
