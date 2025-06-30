// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

enum BackupImportInput {
    case decrypted([PasswordData], tags: [ItemTagData], deleted: [DeletedItemData])
    case encrypted(entropy: Entropy, masterKey: MasterKey, vault: ExchangeVault)
}

protocol BackupImportImportingModuleInteracting: AnyObject {
    func importPasswords(completion: @escaping (Result<Int, Error>) -> Void)
}

final class BackupImportImportingModuleInteractor {
    private let passwordImportInteractor: PasswordImportInteracting
    private let importInteractor: ImportInteracting
    private let input: BackupImportInput
    
    init(
        passwordImportInteractor: PasswordImportInteracting,
        importInteractor: ImportInteracting,
        input: BackupImportInput
    ) {
        self.passwordImportInteractor = passwordImportInteractor
        self.importInteractor = importInteractor
        self.input = input
    }
}

extension BackupImportImportingModuleInteractor: BackupImportImportingModuleInteracting {
    func importPasswords(completion: @escaping (Result<Int, Error>) -> Void) {
        switch input {
        case .decrypted(let passwords, let tags, deleted: let deleted):
            passwordImportInteractor.importDeleted(deleted)
            passwordImportInteractor.importPasswords(passwords, tags: tags, completion: {
                completion(.success($0))
            })
        
        case .encrypted(_, let masterKey, let vault):
            importInteractor.extractPasswordsUsingMasterKey(masterKey, exchangeVault: vault) { result in
                switch result {
                case .success((let passwords, let tags, let deleted)):
                    self.passwordImportInteractor.importDeleted(deleted)
                    self.passwordImportInteractor.importPasswords(passwords, tags: tags, completion: {
                        completion(.success($0))
                    })
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
