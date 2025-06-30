// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryCell: View {
    
    let vaultID: String
    let deviceName: String
    let updatedAt: Date
    let canBeUsed: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("restore_cloud_files_id \(vaultID)")
                        .font(.caption2)
                        .foregroundStyle(.neutral600)
                        .padding(.bottom, Spacing.xxs)
                    
                    Text(deviceName)
                        .font(.bodyEmphasized)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.neutral950)
                    
                    Text("restore_cloud_files_updated_at \(Text(updatedAt.formatted(date: .numeric, time: .standard)))")
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.neutral600)
                }
                
                if canBeUsed == false {
                    HStack {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundStyle(Color.danger400)
                            .blinking()
                        
                        Text("This Vault was created using newer version of the app. Update the app" as String)
                            .multilineTextAlignment(.leading)
                            .font(.caption)
                            .foregroundStyle(Asset.destructiveActionColor.swiftUIColor)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.forward")
                .frame(width: 20, height: 20)
                .foregroundStyle(.neutral500)
        }
        .listRowInsets(EdgeInsets(top: Spacing.l, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l))
    }
}

#Preview {
    List {
        Section {
            VaultRecoveryCell(vaultID: "123", deviceName: "Device name", updatedAt: Date(), canBeUsed: true)
        }
        
        Section {
            VaultRecoveryCell(vaultID: "123", deviceName: "Device name", updatedAt: Date(), canBeUsed: false)
        }
    }
    .listSectionSpacing(8)
    .listStyle(.insetGrouped)
}
