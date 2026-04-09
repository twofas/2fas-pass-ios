// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
@testable import Data

final class MockVaultsInteractor: VaultsInteracting {
    private var stubbedDefaultVaultID: VaultID = UUID()
    private var stubbedDefaultVault: VaultData?
    private var stubbedListVaults: [VaultData] = []

    @discardableResult
    func withDefaultVaultID(_ id: VaultID) -> Self {
        stubbedDefaultVaultID = id
        return self
    }

    @discardableResult
    func withDefaultVault(_ vault: VaultData?) -> Self {
        stubbedDefaultVault = vault
        if let vault {
            stubbedDefaultVaultID = vault.vaultID
            if !stubbedListVaults.contains(where: { $0.vaultID == vault.vaultID }) {
                stubbedListVaults = [vault]
            }
        }
        return self
    }

    @discardableResult
    func withListVaults(_ vaults: [VaultData]) -> Self {
        stubbedListVaults = vaults
        return self
    }

    var hasVault: Bool {
        !stubbedListVaults.isEmpty
    }

    var defaultVaultID: VaultID {
        stubbedDefaultVaultID
    }

    var defaultVault: VaultData? {
        stubbedDefaultVault
    }

    func listVaults() -> [VaultData] {
        stubbedListVaults
    }

    func listEncryptedVaults() -> [VaultEncryptedData] {
        []
    }

    func vault(for vaultID: VaultID) -> VaultData? {
        stubbedListVaults.first { $0.vaultID == vaultID }
    }

    func createNewVault(masterKey: Data, appKey: Data, vaultID: VaultID, name: String, color: String?, icon: String?, creationDate: Date?, modificationDate: Date?) -> VaultID? {
        vaultID
    }

    func changeVaultKeys(vaultID: VaultID, with masterKey: Data, appKey: Data) -> Bool {
        true
    }

    func updateVault(_ vaultID: VaultID, name: String, color: String?, icon: String?, updatedAt: Date) {
        guard let index = stubbedListVaults.firstIndex(where: { $0.vaultID == vaultID }) else { return }
        let vault = stubbedListVaults[index]
        stubbedListVaults[index] = VaultData(
            vaultID: vault.vaultID,
            name: name,
            createdAt: vault.createdAt,
            updatedAt: updatedAt,
            isEmpty: vault.isEmpty,
            color: color,
            icon: icon
        )
    }

    func deleteVault(_ vaultID: VaultID) {
        stubbedListVaults.removeAll { $0.vaultID == vaultID }
    }

    func saveStorage() {}
}
