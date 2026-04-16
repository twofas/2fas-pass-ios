// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CommonUI

struct VaultViewModel: Identifiable {
    let id: VaultID
    let name: String
    let itemCount: Int
    let createdAt: Date
    let isDefault: Bool
    let color: VaultColor
    let icon: String?
}

@Observable @MainActor
final class ManageVaultsPresenter {
    private(set) var vaults: [VaultViewModel] = []

    var isShowingVaultEditor = false
    var editorVaultName = ""
    var editorVaultColor: VaultColor = .gray
    var editorVaultIcon = ""
    private(set) var editingVaultID: VaultID?

    var isShowingDeleteConfirmation = false
    private(set) var vaultToDelete: VaultViewModel?

    var isEditing: Bool { editingVaultID != nil }

    private let interactor: ManageVaultsModuleInteracting

    init(interactor: ManageVaultsModuleInteracting) {
        self.interactor = interactor
    }

    func onAppear() {
        refresh()
    }

    func onAddVault() {
        editingVaultID = nil
        editorVaultName = ""
        editorVaultColor = .gray
        editorVaultIcon = ""
        isShowingVaultEditor = true
    }

    func onEditVault(_ vault: VaultViewModel) {
        editingVaultID = vault.id
        editorVaultName = vault.name
        editorVaultColor = vault.color
        editorVaultIcon = vault.icon ?? ""
        isShowingVaultEditor = true
    }

    func onConfirmVaultEditor() {
        let name = editorVaultName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let colorRaw = editorVaultColor.rawValue
        let icon = editorVaultIcon.isEmpty ? nil : editorVaultIcon

        if let vaultID = editingVaultID {
            interactor.editVault(vaultID, name: name, color: colorRaw, icon: icon)
        } else {
            interactor.createVault(name: name, color: colorRaw, icon: icon)
        }
        editingVaultID = nil
        isShowingVaultEditor = false
        refresh()
    }

    func onDeleteVault(_ vault: VaultViewModel) {
        vaultToDelete = vault
        isShowingDeleteConfirmation = true
    }

    func onConfirmDeleteVault() {
        guard let vault = vaultToDelete else { return }
        interactor.deleteVault(vault.id)
        vaultToDelete = nil
        refresh()
    }

    private func refresh() {
        let defaultID = interactor.defaultVaultID
        let counts = interactor.itemCountPerVault()
        vaults = interactor.listVaults().map { vault in
            VaultViewModel(
                id: vault.vaultID,
                name: vault.name,
                itemCount: counts[vault.vaultID] ?? 0,
                createdAt: vault.createdAt,
                isDefault: vault.vaultID == defaultID,
                color: VaultColor(rawValue: vault.color),
                icon: vault.icon
            )
        }
    }
}
