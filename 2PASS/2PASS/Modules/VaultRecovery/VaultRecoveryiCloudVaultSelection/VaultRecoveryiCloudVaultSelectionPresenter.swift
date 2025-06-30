// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

enum VaultRecoveryiCloudVaultSelectionState: Hashable {
    case loading
    case error(String)
    case list([VaultRecoveryiCloudVaultSelectionEntry])
    case empty
}

struct VaultRecoveryiCloudVaultSelectionEntry: Hashable {
    let id: UUID
    let name: String
    let updatedAt: Date
    let deviceName: String
    let canBeUsed: Bool
    let vaultRawData: VaultRawData
}

@Observable
final class VaultRecoveryiCloudVaultSelectionPresenter {
    private let interactor: VaultRecoveryiCloudVaultSelectionModuleInteracting
    private let jsonDecoder: JSONDecoder
    private let dateFormatter: DateFormatter
    private let onSelect: (VaultRecoveryData) -> Void
    
    var state: VaultRecoveryiCloudVaultSelectionState = .loading
    
    init(
        interactor: VaultRecoveryiCloudVaultSelectionModuleInteracting,
        onSelect: @escaping (VaultRecoveryData) -> Void,
    ) {
        self.interactor = interactor
        self.jsonDecoder = JSONDecoder()
        self.dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        self.onSelect = onSelect
    }

    func onAppear() {
        fetchList()
    }
    
    func retry() {
        fetchList()
    }
    
    func onSelect(vault: VaultRawData) {
        onSelect(.cloud(vault))
    }
}

private extension VaultRecoveryiCloudVaultSelectionPresenter {
    
    func fetchList() {
        interactor.listVaultsToRecover { [weak self] result in
            switch result {
            case .success(let vaults):
                guard let formattedVaults = self?.prepareVaults(vaults), !formattedVaults.isEmpty else {
                    self?.state = .empty
                    return
                }
                self?.state = .list(formattedVaults)
            case .failure(let error):
                self?.state = .error(error.localizedDescription)
            }
        }
    }
    
    func prepareVaults(_ vaults: [VaultRawData]) -> [VaultRecoveryiCloudVaultSelectionEntry] {
        vaults.compactMap { vault -> VaultRecoveryiCloudVaultSelectionEntry? in
            guard let deviceNames = try? jsonDecoder.decode([DeviceName].self, from: vault.deviceNames),
                  let device = deviceNames.first
            else {
                return nil
            }
            
            return VaultRecoveryiCloudVaultSelectionEntry(
                id: vault.vaultID,
                name: vault.name,
                updatedAt: vault.updatedAt,
                deviceName: device.deviceName,
                canBeUsed: vault.schemaVersion <= Config.cloudSchemaVersion,
                vaultRawData: vault
            )
        }
    }
}
