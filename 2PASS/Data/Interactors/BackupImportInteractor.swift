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
    case decrypted([ItemData], tags: [ItemTagData], deleted: [DeletedItemData], date: Date, vaultName: String, deviceName: String?, itemsCount: Int)
    case needsPassword(ExchangeVaultVersioned, currentSeed: Bool, date: Date, vaultName: String, deviceName: String?, itemsCount: Int)
}

public enum BackupImportWithoutEncryptionResult {
    case decrypted(ExchangeVaultVersioned, date: Date, vaultName: String, deviceName: String?, itemsCount: Int)
    case needsPassword(ExchangeVaultVersioned, date: Date, vaultName: String, deviceName: String?, itemsCount: Int)
}

public enum BackupImportParseError: Error {
    case corruptedFile(Error)
    case nothingToImport
    case errorDecrypting
    case otherDeviceId
    case passwordChanged
    case schemaNotSupported(Int)
}

public protocol BackupImportInteracting: AnyObject {
    func openFile(url: URL, completion: @escaping (Result<Data, BackupImportFileError>) -> Void)
    func extractItems(from vault: ExchangeVaultVersioned) -> [ItemData]?
    func extractDeletedItems(from vault: ExchangeVaultVersioned) -> [DeletedItemData]?
    func extractTags(from vault: ExchangeVaultVersioned) -> [ItemTagData]?
    func parseContents(
        of data: Data,
        decryptItemsIfPossible: Bool,
        allowsAnyDeviceId: Bool,
        completion: @escaping (Result<BackupImportResult, BackupImportParseError>) -> Void
    )
    func parseContentsWithoutEncryption(
        of data: Data,
        completion: @escaping (Result<BackupImportWithoutEncryptionResult, BackupImportParseError>) -> Void
    )
    func isVaultReadyForImport() -> Bool
    func parseRaw(data: Data, completion: @escaping (Result<ExchangeVaultVersioned, ImportParseError>) -> Void)
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
                let itemsCount = summary.itemsCount
                switch importInteractor.checkEncryptionWithoutParsing(in: data) {
                case .noEncryption:
                    completion(
                        .success(
                            .decrypted(
                                data,
                                date: date,
                                vaultName: vaultName,
                                deviceName: devideName,
                                itemsCount: itemsCount
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
                                itemsCount: itemsCount
                            )
                        )
                    )
                }
            case .failure(let error):
                switch error {
                case .jsonError(let reason): completion(.failure(.corruptedFile(reason)))
                case .nothingToImport: completion(.failure(.nothingToImport))
                case .schemaNotSupported(let schemaVersion): completion(.failure(.schemaNotSupported(schemaVersion)))
                }
            }
        }
    }
    
    func extractItems(from vault: ExchangeVaultVersioned) -> [ItemData]? {
        importInteractor.extractUnencryptedItems(from: vault)
    }

    func extractDeletedItems(from vault: ExchangeVaultVersioned) -> [DeletedItemData]? {
        importInteractor.extractUnencryptedDeletedItems(from: vault)
    }

    func extractTags(from vault: ExchangeVaultVersioned) -> [ItemTagData]? {
        importInteractor.extractUnencryptedTags(from: vault)
    }

    func parseRaw(data: Data, completion: @escaping (Result<ExchangeVaultVersioned, ImportParseError>) -> Void) {
        importInteractor.parseContents(of: data, completion: completion)
    }
    
    func parseContents(
        of data: Data,
        decryptItemsIfPossible: Bool,
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
                let itemsCount = summary.itemsCount
                switch self?.importInteractor.checkEncryption(in: data) {
                case .noEncryption:
                    completion(
                        .success(
                            .decrypted(
                                self?.importInteractor.extractUnencryptedItems(from: data) ?? [],
                                tags: self?.importInteractor.extractUnencryptedTags(from: data) ?? [],
                                deleted: self?.importInteractor.extractUnencryptedDeletedItems(from: data) ?? [],
                                date: date,
                                vaultName: vaultName,
                                deviceName: devideName,
                                itemsCount: itemsCount
                            )
                        )
                    )
                case .noExternalKeyError, .noSelectedVaultError, .missingEncryptionError: completion(.failure(.errorDecrypting))
                case .currentEncryption:
                    if decryptItemsIfPossible {
                        self?.importInteractor.extractItemsUsingCurrentEncryption(from: data, completion: { decryptResult in
                            switch decryptResult {
                            case .success((let items, let tags, let deleted)): completion(
                                .success(
                                    .decrypted(
                                        items,
                                        tags: tags,
                                        deleted: deleted,
                                        date: date,
                                        vaultName: vaultName,
                                        deviceName: devideName,
                                        itemsCount: itemsCount
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
                                itemsCount: itemsCount
                            )
                        ))
                    }
                case .passwordChanged:
                    if decryptItemsIfPossible {
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
                                    itemsCount: itemsCount
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
                            itemsCount: itemsCount
                        )
                    )
                )
                default: completion(.failure(.errorDecrypting))
                }
            case .failure(let error):
                switch error {
                case .jsonError(let reason): completion(.failure(.corruptedFile(reason)))
                case .nothingToImport: completion(.failure(.nothingToImport))
                case .schemaNotSupported(let actualVersion): completion(.failure(.schemaNotSupported(actualVersion)))
                }
            }
        }
    }
}
