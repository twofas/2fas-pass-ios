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
    case decrypted([ItemDecryptedData], tags: [ItemTagData], deleted: [DeletedItemData], date: Date, vaultName: String, deviceName: String?, itemsCount: Int)
    case encryptedForCurrentVault([ItemData], tags: [ItemTagData], deleted: [DeletedItemData], date: Date, vaultName: String, deviceName: String?, itemsCount: Int)
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
    func openFile(url: URL) async throws(BackupImportFileError) -> Data
    func extractItems(from vault: ExchangeVaultVersioned) -> [ItemData]?
    func extractDeletedItems(from vault: ExchangeVaultVersioned) -> [DeletedItemData]?
    func extractTags(from vault: ExchangeVaultVersioned) -> [ItemTagData]?
    func parseContents(
        of data: Data,
        decryptItemsIfPossible: Bool,
        preferCurrentVaultEncryption: Bool,
        allowsAnyDeviceId: Bool
    ) async throws -> BackupImportResult
    func parseContentsWithoutEncryption(of data: Data) async throws -> BackupImportWithoutEncryptionResult
    func isVaultReadyForImport() -> Bool
    func parseRaw(data: Data) async throws(ImportParseError) -> ExchangeVaultVersioned
    func encryptItem(_ decrypted: ItemDecryptedData, forVault targetVaultID: VaultID) -> ItemData?
    func rebindTag(_ tag: ItemTagData, forVault targetVaultID: VaultID) -> ItemTagData
}

final class BackupImportInteractor {
    private let importInteractor: ImportInteracting

    init(importInteractor: ImportInteracting) {
        self.importInteractor = importInteractor
    }
}

extension BackupImportInteractor: BackupImportInteracting {
    func openFile(url: URL) async throws(BackupImportFileError) -> Data {
        do {
            return try await importInteractor.openFile(url: url)
        } catch let error as ImportOpenFileError {
            switch error {
            case .cantReadFile(let reason): throw .cantReadFile(reason: reason)
            }
        }
    }

    func isVaultReadyForImport() -> Bool {
        importInteractor.isVaultReadyForImport()
    }

    func parseContentsWithoutEncryption(of data: Data) async throws -> BackupImportWithoutEncryptionResult {
        let parsed: ExchangeVaultVersioned
        do {
            parsed = try await importInteractor.parseContents(of: data)
        } catch {
            throw BackupImportParseError(error)
        }

        let summary = parsed.summary
        switch importInteractor.checkEncryptionWithoutParsing(in: parsed) {
        case .noEncryption:
            return .decrypted(
                parsed,
                date: summary.date,
                vaultName: summary.vaultName,
                deviceName: summary.deviceName,
                itemsCount: summary.itemsCount
            )
        case .needsPassword:
            return .needsPassword(
                parsed,
                date: summary.date,
                vaultName: summary.vaultName,
                deviceName: summary.deviceName,
                itemsCount: summary.itemsCount
            )
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

    func parseRaw(data: Data) async throws(ImportParseError) -> ExchangeVaultVersioned {
        try await importInteractor.parseContents(of: data)
    }

    func encryptItem(_ decrypted: ItemDecryptedData, forVault targetVaultID: VaultID) -> ItemData? {
        importInteractor.encryptItem(decrypted, forVault: targetVaultID)
    }

    func rebindTag(_ tag: ItemTagData, forVault targetVaultID: VaultID) -> ItemTagData {
        importInteractor.rebindTag(tag, forVault: targetVaultID)
    }

    func parseContents(
        of data: Data,
        decryptItemsIfPossible: Bool,
        preferCurrentVaultEncryption: Bool,
        allowsAnyDeviceId: Bool
    ) async throws -> BackupImportResult {
        let parsed: ExchangeVaultVersioned
        do {
            parsed = try await importInteractor.parseContents(of: data)
        } catch {
            throw BackupImportParseError(error)
        }

        guard allowsAnyDeviceId || importInteractor.checkDeviceId(in: parsed) else {
            throw BackupImportParseError.otherDeviceId
        }

        let summary = parsed.summary
        let date = summary.date
        let vaultName = summary.vaultName
        let deviceName = summary.deviceName
        let itemsCount = summary.itemsCount

        switch importInteractor.checkEncryption(in: parsed) {
        case .noEncryption:
            return .decrypted(
                importInteractor.extractDecryptedUnencryptedItems(from: parsed),
                tags: importInteractor.extractUnencryptedTags(from: parsed),
                deleted: importInteractor.extractUnencryptedDeletedItems(from: parsed),
                date: date,
                vaultName: vaultName,
                deviceName: deviceName,
                itemsCount: itemsCount
            )

        case .noExternalKeyError, .noSelectedVaultError, .missingEncryptionError:
            throw BackupImportParseError.errorDecrypting

        case .currentEncryption:
            if decryptItemsIfPossible {
                if preferCurrentVaultEncryption {
                    do {
                        let (items, tags, deleted) = try await importInteractor.extractDataUsingCurrentEncryption(from: parsed)
                        return .encryptedForCurrentVault(
                            items, tags: tags, deleted: deleted,
                            date: date, vaultName: vaultName, deviceName: deviceName, itemsCount: itemsCount
                        )
                    } catch {
                        throw BackupImportParseError.errorDecrypting
                    }
                } else {
                    do {
                        let (items, tags, deleted) = try await importInteractor.extractDecryptedDataUsingCurrentEncryption(from: parsed)
                        return .decrypted(
                            items, tags: tags, deleted: deleted,
                            date: date, vaultName: vaultName, deviceName: deviceName, itemsCount: itemsCount
                        )
                    } catch {
                        throw BackupImportParseError.errorDecrypting
                    }
                }
            } else {
                return .needsPassword(
                    parsed, currentSeed: true,
                    date: date, vaultName: vaultName, deviceName: deviceName, itemsCount: itemsCount
                )
            }

        case .passwordChanged:
            if decryptItemsIfPossible {
                throw BackupImportParseError.passwordChanged
            } else {
                return .needsPassword(
                    parsed, currentSeed: true,
                    date: date, vaultName: vaultName, deviceName: deviceName, itemsCount: itemsCount
                )
            }

        case .needsPasswordWords:
            return .needsPassword(
                parsed, currentSeed: false,
                date: date, vaultName: vaultName, deviceName: deviceName, itemsCount: itemsCount
            )
        }
    }
}

private extension BackupImportParseError {
    init(_ importError: ImportParseError) {
        switch importError {
        case .jsonError(let reason): self = .corruptedFile(reason)
        case .nothingToImport: self = .nothingToImport
        case .schemaNotSupported(let version): self = .schemaNotSupported(version)
        }
    }
}
