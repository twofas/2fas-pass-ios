// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

enum BackupImportInput {
    case decrypted([ItemData], tags: [ItemTagData], deleted: [DeletedItemData])
    case encrypted(entropy: Entropy, masterKey: MasterKey, vault: ExchangeVaultVersioned)
}

protocol BackupImportImportingModuleInteracting: AnyObject {
    func importItems(completion: @escaping (Result<Int, Error>) -> Void)
}

final class BackupImportImportingModuleInteractor {
    private let itemsImportInteractor: ItemsImportInteracting
    private let importInteractor: ImportInteracting
    private let input: BackupImportInput
    private let targetVaultID: VaultID?

    /// - Parameter targetVaultID: When non-nil, every imported item's `vaultId` is
    ///   rewritten to this vault before insertion. When nil, items keep their original
    ///   `vaultId` from the backup (used by the encrypted/recovery flow, which doesn't
    ///   go through the import-summary screen).
    init(
        itemsImportInteractor: ItemsImportInteracting,
        importInteractor: ImportInteracting,
        input: BackupImportInput,
        targetVaultID: VaultID?
    ) {
        self.itemsImportInteractor = itemsImportInteractor
        self.importInteractor = importInteractor
        self.input = input
        self.targetVaultID = targetVaultID
    }

    private func retargeted(_ items: [ItemData]) -> [ItemData] {
        guard let targetVaultID else { return items }
        return items.map { $0.update(vaultId: targetVaultID) }
    }
}

extension BackupImportImportingModuleInteractor: BackupImportImportingModuleInteracting {
    func importItems(completion: @escaping (Result<Int, Error>) -> Void) {
        switch input {
        case .decrypted(let items, let tags, deleted: let deleted):
            itemsImportInteractor.importDeleted(deleted)
            itemsImportInteractor.importItems(retargeted(items), tags: tags, completion: {
                completion(.success($0))
            })

        case .encrypted(_, let masterKey, let vault):
            importInteractor.extractItemsUsingMasterKey(masterKey, exchangeVault: vault) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success((let items, let tags, let deleted)):
                    self.itemsImportInteractor.importDeleted(deleted)
                    self.itemsImportInteractor.importItems(self.retargeted(items), tags: tags, completion: {
                        completion(.success($0))
                    })
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
