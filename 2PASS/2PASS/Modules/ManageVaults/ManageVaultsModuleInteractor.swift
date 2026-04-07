// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data

protocol ManageVaultsModuleInteracting: AnyObject {
    var defaultVaultID: VaultID { get }
    func listVaults() -> [VaultData]
    func vaultItemCount(_ vaultID: VaultID) -> Int
    func createVault(name: String, color: String?, icon: String?)
    func editVault(_ vaultID: VaultID, name: String, color: String?, icon: String?)
    func deleteVault(_ vaultID: VaultID)
}

final class ManageVaultsModuleInteractor: ManageVaultsModuleInteracting {
    private let vaultsInteractor: VaultsInteracting
    private let itemsInteractor: ItemsInteracting
    private let protectionInteractor: ProtectionInteracting
    private let currentDateInteractor: CurrentDateInteracting

    init(
        vaultsInteractor: VaultsInteracting,
        itemsInteractor: ItemsInteracting,
        protectionInteractor: ProtectionInteracting,
        currentDateInteractor: CurrentDateInteracting
    ) {
        self.vaultsInteractor = vaultsInteractor
        self.itemsInteractor = itemsInteractor
        self.protectionInteractor = protectionInteractor
        self.currentDateInteractor = currentDateInteractor
    }

    func listVaults() -> [VaultData] {
        vaultsInteractor.listVaults()
    }

    func vaultItemCount(_ vaultID: VaultID) -> Int {
        itemsInteractor.listItems(
            searchPhrase: nil,
            tagId: nil,
            vaultId: vaultID,
            contentTypes: nil,
            protectionLevel: nil,
            sortBy: .az,
            trashed: .no
        ).count
    }

    var defaultVaultID: VaultID {
        vaultsInteractor.defaultVaultID
    }

    func createVault(name: String, color: String?, icon: String?) {
        let vaultID = VaultID()
        protectionInteractor.createNewVault(with: vaultID, name: name, color: color, icon: icon, creationDate: nil, modificationDate: nil)
        vaultsInteractor.saveStorage()
    }

    func editVault(_ vaultID: VaultID, name: String, color: String?, icon: String?) {
        vaultsInteractor.updateVault(vaultID, name: name, color: color, icon: icon, updatedAt: currentDateInteractor.currentDate)
        vaultsInteractor.saveStorage()
    }

    func deleteVault(_ vaultID: VaultID) {
        vaultsInteractor.deleteVault(vaultID)
        vaultsInteractor.saveStorage()
    }
}
