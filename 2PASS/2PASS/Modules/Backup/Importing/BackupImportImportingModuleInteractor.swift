// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

enum BackupImportInput {
    case decrypted([ItemDecryptedData], tags: [ItemTagData], deleted: [DeletedItemData])
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

    private func encryptForWrite(
        items: [ItemDecryptedData],
        tags: [ItemTagData],
        targetVaultID: VaultID
    ) -> (items: [ItemData], tags: [ItemTagData]) {
        let readyItems: [ItemData] = items.compactMap { importInteractor.encryptItem($0, forVault: targetVaultID) }
        let readyTags = tags.map { importInteractor.rebindTag($0, forVault: targetVaultID) }
        return (readyItems, readyTags)
    }
}

extension BackupImportImportingModuleInteractor: BackupImportImportingModuleInteracting {
    func importItems(completion: @escaping (Result<Int, Error>) -> Void) {
        switch input {
        case .decrypted(let decItems, let decTags, let deleted):
            // `.decrypted` input is only produced by the summary, which always supplies a target.
            // Tags have no source vaultID to fall back to, so the guard is strict here.
            guard let target = targetVaultID else {
                Log("BackupImportImportingModuleInteractor - .decrypted requires targetVaultID", severity: .error)
                completion(.failure(ImportExtractCurrentEncryptionError.noVaultID))
                return
            }
            let ready = encryptForWrite(items: decItems, tags: decTags, targetVaultID: target)
            itemsImportInteractor.importDeleted(deleted)
            itemsImportInteractor.importItems(ready.items, tags: ready.tags, completion: {
                completion(.success($0))
            })

        case .encrypted(_, let masterKey, let vault):
            let fallbackTarget = UUID(uuidString: vault.vaultID)
            Task { [weak self] in
                do {
                    let (decItems, decTags, deleted) = try await importInteractor.extractDecryptedItemsUsingMasterKey(masterKey, exchangeVault: vault)
                    guard let self else { return }
                    guard let target = self.targetVaultID ?? fallbackTarget else {
                        completion(.failure(ImportExtractCurrentEncryptionError.noVaultID))
                        return
                    }
                    let ready = self.encryptForWrite(items: decItems, tags: decTags, targetVaultID: target)
                    self.itemsImportInteractor.importDeleted(deleted)
                    self.itemsImportInteractor.importItems(ready.items, tags: ready.tags, completion: {
                        completion(.success($0))
                    })
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}
