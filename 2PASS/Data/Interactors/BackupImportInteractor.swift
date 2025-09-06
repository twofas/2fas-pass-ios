// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum BackupImportFileError: Error {
    case cantReadFile(reason: String?)
}

public enum BackupImportResult {
    case decrypted([ItemData], tags: [ItemTagData], deleted: [DeletedItemData], date: Date, vaultName: String, deviceName: String?, passwordCount: Int)
    case needsPassword(ExchangeVault, currentSeed: Bool, date: Date, vaultName: String, deviceName: String?, passwordCount: Int)
}

public enum BackupImportWithoutEncryptionResult {
    case decrypted(ExchangeVault, date: Date, vaultName: String, deviceName: String?, passwordCount: Int)
    case needsPassword(ExchangeVault, date: Date, vaultName: String, deviceName: String?, passwordCount: Int)
}

public enum BackupImportParseError: Error {
    case corruptedFile(Error)
    case newerSchemaVersion
    case nothingToImport
    case errorDecrypting
    case otherDeviceId
    case passwordChanged
}

public protocol BackupImportInteracting: AnyObject {
    func openFile(url: URL, completion: @escaping (Result<Data, BackupImportFileError>) -> Void)
    func extractPasswords(from vault: ExchangeVault) -> [ItemData]?
    func extractDeletedItems(from vault: ExchangeVault) -> [DeletedItemData]?
    func extractTags(from vault: ExchangeVault) -> [ItemTagData]?
    func parseContents(
        of data: Data,
        decryptPasswordsIfPossible: Bool,
        allowsAnyDeviceId: Bool,
        completion: @escaping (Result<BackupImportResult, BackupImportParseError>) -> Void
    )
    func parseContentsWithoutEncryption(
        of data: Data,
        completion: @escaping (Result<BackupImportWithoutEncryptionResult, BackupImportParseError>) -> Void
    )
    func isVaultReadyForImport() -> Bool
    func parseRaw(data: Data, completion: @escaping (Result<ExchangeVault, ImportParseError>) -> Void)
}

final class BackupImportInteractor {
    private let importInteractor: ImportInteracting

    init(importInteractor: ImportInteracting) {
        self.importInteractor = importInteractor
    }
}

extension BackupImportInteractor: BackupImportInteracting {
    func openFile(url: URL, completion: @escaping (Result<Data, BackupImportFileError>) -> Void) {
        importInteractor.openFile(url: url) { result in
            switch result {
            case .success(let data): completion(.success(data))
            case .failure(let error):
                switch error {
                case .cantReadFile(let reason): completion(.failure(.cantReadFile(reason: reason)))
                }
            }
        }
    }
    
    func isVaultReadyForImport() -> Bool {
        importInteractor.isVaultReadyForImport()
    }
    
    func parseContentsWithoutEncryption(
        of data: Data,
        completion: @escaping (Result<BackupImportWithoutEncryptionResult, BackupImportParseError>) -> Void
    ) {
        importInteractor.parseContents(of: data) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                let summary = data.summary
                let devideName = summary.deviceName
                let date = summary.date
                let vaultName = summary.vaultName
                let passwordCount = summary.passwordCount
                switch importInteractor.checkEncryptionWithoutParsing(in: data) {
                case .noEncryption:
                    completion(
                        .success(
                            .decrypted(
                                data,
                                date: date,
                                vaultName: vaultName,
                                deviceName: devideName,
                                passwordCount: passwordCount
                            )
                        )
                    )
                case .needsPassword:
                    completion(
                        .success(
                            .needsPassword(
                                data,
                                date: date,
                                vaultName: vaultName,
                                deviceName: devideName,
                                passwordCount: passwordCount
                            )
                        )
                    )
                }
            case .failure(let error):
                switch error {
                case .jsonError(let reason): completion(.failure(.corruptedFile(reason)))
                case .newerSchemaVersion: completion(.failure(.newerSchemaVersion))
                case .nothingToImport: completion(.failure(.nothingToImport))
                }
            }
        }
    }
    
    func extractPasswords(from vault: ExchangeVault) -> [ItemData]? {
        importInteractor.extractUnencryptedPasswords(from: vault)
    }
    
    func extractDeletedItems(from vault: ExchangeVault) -> [DeletedItemData]? {
        importInteractor.extractUnencryptedDeletedItems(from: vault)
    }
    
    func extractTags(from vault: ExchangeVault) -> [ItemTagData]? {
        importInteractor.extractUnencryptedTags(from: vault)
    }
    
    func parseRaw(data: Data, completion: @escaping (Result<ExchangeVault, ImportParseError>) -> Void) {
        importInteractor.parseContents(of: data, completion: completion)
    }
    
    func parseContents(
        of data: Data,
        decryptPasswordsIfPossible: Bool,
        allowsAnyDeviceId: Bool,
        completion: @escaping (Result<BackupImportResult, BackupImportParseError>) -> Void
    ) {
        importInteractor.parseContents(of: data) { [weak self, importInteractor] result in
            switch result {
            case .success(let data):
                guard allowsAnyDeviceId || importInteractor.checkDeviceId(in: data) else {
                    completion(.failure(.otherDeviceId))
                    return
                }

                let summary = data.summary
                let devideName = summary.deviceName
                let date = summary.date
                let vaultName = summary.vaultName
                let passwordCount = summary.passwordCount
                switch self?.importInteractor.checkEncryption(in: data) {
                case .noEncryption:
                    completion(
                        .success(
                            .decrypted(
                                self?.importInteractor.extractUnencryptedPasswords(from: data) ?? [],
                                tags: self?.importInteractor.extractUnencryptedTags(from: data) ?? [],
                                deleted: self?.importInteractor.extractUnencryptedDeletedItems(from: data) ?? [],
                                date: date,
                                vaultName: vaultName,
                                deviceName: devideName,
                                passwordCount: passwordCount
                            )
                        )
                    )
                case .noExternalKeyError, .noSelectedVaultError, .missingEncryptionError: completion(.failure(.errorDecrypting))
                case .currentEncryption:
                    if decryptPasswordsIfPossible {
                        self?.importInteractor.extractPasswordsUsingCurrentEncryption(from: data, completion: { decryptResult in
                            switch decryptResult {
                            case .success((let passwords, let tags, let deleted)): completion(
                                .success(
                                    .decrypted(
                                        passwords,
                                        tags: tags,
                                        deleted: deleted,
                                        date: date,
                                        vaultName: vaultName,
                                        deviceName: devideName,
                                        passwordCount: passwordCount
                                    )
                                )
                            )
                            case .failure: completion(.failure(.errorDecrypting))
                            }
                        })
                    } else {
                        completion(.success(
                            .needsPassword(
                                data,
                                currentSeed: true,
                                date: date,
                                vaultName: vaultName,
                                deviceName: devideName,
                                passwordCount: passwordCount
                            )
                        ))
                    }
                case .passwordChanged:
                    if decryptPasswordsIfPossible {
                        completion(.failure(.passwordChanged))
                    } else {
                        completion(
                            .success(
                                .needsPassword(
                                    data,
                                    currentSeed: true,
                                    date: date,
                                    vaultName: vaultName,
                                    deviceName: devideName,
                                    passwordCount: passwordCount
                                )
                            )
                        )
                    }
                case .needsPasswordWords: completion(
                    .success(
                        .needsPassword(
                            data,
                            currentSeed: false,
                            date: date,
                            vaultName: vaultName,
                            deviceName: devideName,
                            passwordCount: passwordCount
                        )
                    )
                )
                default: completion(.failure(.errorDecrypting))
                }
            case .failure(let error):
                switch error {
                case .jsonError(let reason): completion(.failure(.corruptedFile(reason)))
                case .newerSchemaVersion: completion(.failure(.newerSchemaVersion))
                case .nothingToImport: completion(.failure(.nothingToImport))
                }
            }
        }
    }
}
