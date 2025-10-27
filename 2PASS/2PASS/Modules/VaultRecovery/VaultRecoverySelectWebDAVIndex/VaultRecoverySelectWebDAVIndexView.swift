// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct VaultRecoverySelectWebDAVIndexView: View {
    
    @State
    var presenter: VaultRecoverySelectWebDAVIndexPresenter
        
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        VStack {
            if presenter.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .tint(nil)
            } else {
                List {
                    ForEach(Array(presenter.backups.enumerated()), id: \.1) { index, vault in
                        Section {
                            Button {
                                presenter.onSelectVault(vault)
                            } label: {
                                VaultRecoveryCell(
                                    vaultID: vault.vaultId,
                                    deviceName: vault.deviceName,
                                    updatedAt: Date(exportTimestamp: vault.vaultUpdatedAt),
                                    canBeUsed: vault.schemaVersion <= Config.cloudSchemaVersion
                                )
                            }
                        } header: {
                            if index == 0 {
                                Text(T.restoreCloudFilesHeader.localizedKey)
                            }
                        }
                    }
                }
                .listSectionSpacing(Spacing.s)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarCancelButton {
                    dismiss()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(T.restoreCloudFilesTitle.localizedKey)
        .router(router: VaultRecoverySelectWebDAVIndexRouter(), destination: $presenter.destination)
    }
}
