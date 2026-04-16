// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

struct BackupImportSummaryPayload {
    let items: [ItemDecryptedData]
    let tags: [ItemTagData]
    let deleted: [DeletedItemData]
}

protocol BackupImportSummaryModuleInteracting: AnyObject {
    var defaultVaultID: VaultID { get }
    func listVaults() -> [VaultData]
    func extractItems(from input: BackupImportInput) async -> Result<BackupImportSummaryPayload, Error>
}

final class BackupImportSummaryModuleInteractor {
    private let vaultsInteractor: VaultsInteracting
    private let importInteractor: ImportInteracting

    init(vaultsInteractor: VaultsInteracting, importInteractor: ImportInteracting) {
        self.vaultsInteractor = vaultsInteractor
        self.importInteractor = importInteractor
    }
}

extension BackupImportSummaryModuleInteractor: BackupImportSummaryModuleInteracting {

    var defaultVaultID: VaultID {
        vaultsInteractor.defaultVaultID
    }

    func listVaults() -> [VaultData] {
        vaultsInteractor.listVaults()
    }

    func extractItems(from input: BackupImportInput) async -> Result<BackupImportSummaryPayload, Error> {
        switch input {
        case .decrypted(let items, let tags, let deleted):
            return .success(BackupImportSummaryPayload(items: items, tags: tags, deleted: deleted))

        case .encrypted(_, let masterKey, let vault):
            return await withCheckedContinuation { continuation in
                importInteractor.extractDecryptedItemsUsingMasterKey(masterKey, exchangeVault: vault) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: .success(
                            BackupImportSummaryPayload(items: data.0, tags: data.1, deleted: data.2)
                        ))
                    case .failure(let error):
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }
}
