// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct VaultPickerRow: View {
    let label: Text
    let vaults: [VaultData]
    let rowBackground: Color?
    @Binding var selectedVaultID: VaultID?

    public init(
        label: Text,
        vaults: [VaultData],
        selectedVaultID: Binding<VaultID?>,
        rowBackground: Color? = nil
    ) {
        self.label = label
        self.vaults = vaults
        self._selectedVaultID = selectedVaultID
        self.rowBackground = rowBackground
    }

    public var body: some View {
        GroupedSection {
            HStack {
                label

                Spacer()

                Picker(selection: $selectedVaultID) {
                    ForEach(vaults, id: \.vaultID) { vault in
                        Text(vault.name).tag(vault.vaultID)
                    }
                } label: {
                    EmptyView()
                }
            }
            .groupedRowBackground(rowBackground)
        }
    }
}
