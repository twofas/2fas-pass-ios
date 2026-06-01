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

    var body: some View {
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
                            canBeUsed: vault.schemaVersion <= Config.cloudSchemaVersion,
                            isLoading: presenter.selectedVaultID == vault.vaultId
                        )
                    }
                    .disabled(presenter.selectedVaultID != nil && presenter.selectedVaultID != vault.vaultId)
                } header: {
                    if index == 0 {
                        Text(.restoreCloudFilesHeader)
                    }
                }
            }
        }
        .listSectionSpacing(Spacing.s)
        .animation(.easeInOut(duration: 0.25), value: presenter.selectedVaultID)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.restoreCloudFilesTitle)
        .router(router: VaultRecoverySelectWebDAVIndexRouter(), destination: $presenter.destination)
    }
}
