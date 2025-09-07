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
    case encrypted(entropy: Entropy, masterKey: MasterKey, vault: ExchangeVault)
}

protocol BackupImportImportingModuleInteracting: AnyObject {
    func importItems(completion: @escaping (Result<Int, Error>) -> Void)
}

final class BackupImportImportingModuleInteractor {
    private let itemsImportInteractor: ItemsImportInteracting
    private let importInteractor: ImportInteracting
    private let input: BackupImportInput
    
    init(
        itemsImportInteractor: ItemsImportInteracting,
        importInteractor: ImportInteracting,
        input: BackupImportInput
    ) {
        self.itemsImportInteractor = itemsImportInteractor
        self.importInteractor = importInteractor
        self.input = input
    }
}

extension BackupImportImportingModuleInteractor: BackupImportImportingModuleInteracting {
    func importItems(completion: @escaping (Result<Int, Error>) -> Void) {
        switch input {
        case .decrypted(let items, let tags, deleted: let deleted):
            itemsImportInteractor.importDeleted(deleted)
            itemsImportInteractor.importItems(items, tags: tags, completion: {
                completion(.success($0))
            })
        
        case .encrypted(_, let masterKey, let vault):
            importInteractor.extractPasswordsUsingMasterKey(masterKey, exchangeVault: vault) { result in
                switch result {
                case .success((let items, let tags, let deleted)):
                    self.itemsImportInteractor.importDeleted(deleted)
                    self.itemsImportInteractor.importItems(items, tags: tags, completion: {
                        completion(.success($0))
                    })
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
