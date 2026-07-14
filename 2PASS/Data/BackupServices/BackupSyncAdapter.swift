// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

final class BackupSyncAdapter: BackupSyncContext, BackupVaultExporting, BackupLocalMerging, BackupSyncConfigStore, BackupSyncDateStore, BackupAwaitingFlagsStoring, @unchecked Sendable {

    private let mainRepository: MainRepository
    private let exportInteractor: ExportInteracting
    private let backupImportInteractor: BackupImportInteracting
    private let syncInteractor: SyncInteracting

    init(
        mainRepository: MainRepository,
        exportInteractor: ExportInteracting,
        backupImportInteractor: BackupImportInteracting,
        syncInteractor: SyncInteracting
    ) {
        self.mainRepository = mainRepository
        self.exportInteractor = exportInteractor
        self.backupImportInteractor = backupImportInteractor
        self.syncInteractor = syncInteractor
    }

    // MARK: - BackupSyncContext

    var deviceID: UUID? {
        mainRepository.deviceID
    }

    var deviceName: String {
        mainRepository.deviceName
    }

    var allowsMultiDeviceSync: Bool {
        mainRepository.paymentSubscriptionPlan.entitlements.multiDeviceSync
    }

    var vaultID: UUID? {
        mainRepository.listEncryptedVaults().first?.vaultID
    }

    func vault(for vaultID: UUID) async -> VaultEncryptedData? {
        await MainActor.run {
            mainRepository.getEncryptedVault(for: vaultID)
        }
    }

    func seedHash(for vaultID: UUID) -> String? {
        guard let seed = mainRepository.seed else { return nil }
        return mainRepository.generateExchangeSeedHash(vaultID, using: seed)
    }

    func latestContentModification(for vaultID: UUID) async -> Date? {
        await MainActor.run {
            let vault = mainRepository.getEncryptedVault(for: vaultID)
            return [vault?.updatedAt, vault?.contentModificationDate].compactMap { $0 }.max()
        }
    }

#if DEBUG
    var shouldWriteDecryptedCopy: Bool {
        mainRepository.webDAVWriteDecryptedCopy
    }
#endif

    // MARK: - BackupVaultExporting

    func prepareEncryptedExport(
        vaultID: UUID,
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault {
        do {
            return try await exportInteractor.prepareItemsForExport(
                vaultID: vaultID,
                encrypt: true,
                exportIfEmpty: true,
                includeDeletedItems: includeDeleted
            )
        } catch {
            throw Self.mapExportError(error)
        }
    }

#if DEBUG
    func prepareDecryptedExport(
        vaultID: UUID,
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault {
        do {
            return try await exportInteractor.prepareItemsForExport(
                vaultID: vaultID,
                encrypt: false,
                exportIfEmpty: true,
                includeDeletedItems: includeDeleted
            )
        } catch {
            throw Self.mapExportError(error)
        }
    }
#endif

    private static func mapExportError(_ error: ExportError) -> BackupVaultExportError {
        switch error {
        case .noItemsToExport:
            return .empty
        case .noSelectedVault:
            return .other("no selected vault")
        case .missingExternalKey, .encryptionDef:
            return .encryptionFailed
        case .jsonEncode(let underlying):
            return .other("export encode: \(underlying)")
        case .jsonDecode(let underlying):
            return .other("export decode: \(underlying.map(String.init(describing:)) ?? "nil")")
        }
    }

    // MARK: - BackupLocalMerging

    func applyRemoteChanges(
        _ remoteVault: ExchangeVaultVersioned,
        allowingAnyDeviceId: Bool
    ) async throws(BackupLocalMergeError) -> Bool {
        let data: Data
        do {
            data = try Self.encode(remoteVault)
        } catch {
            throw .errorDecrypting
        }

        let parsed: BackupImportResult
        do {
            parsed = try await backupImportInteractor.parseContents(
                of: data,
                decryptItemsIfPossible: true,
                preferCurrentVaultEncryption: true,
                allowsAnyDeviceId: allowingAnyDeviceId
            )
        } catch let error as BackupImportParseError {
            switch error {
            case .errorDecrypting, .corruptedFile, .schemaNotSupported:
                throw .errorDecrypting
            case .otherDeviceId:
                throw .otherDeviceId
            case .passwordChanged:
                throw .passwordChanged
            case .nothingToImport:
                return false
            }
        } catch {
            throw .errorDecrypting
        }

        switch parsed {
        case .decrypted(let decryptedItems, let tags, let deleted, _, _, _, _):
            return await MainActor.run {
                guard let vaultID = self.vaultID else {
                    return false
                }
                let items = decryptedItems.compactMap { backupImportInteractor.encryptItem($0, forVault: vaultID) }
                let reboundTags = tags.map { backupImportInteractor.rebindTag($0, forVault: vaultID) }
                return syncInteractor.syncAndApplyChanges(
                    from: items,
                    externalTags: reboundTags,
                    externalDeleted: deleted,
                    in: vaultID
                )
            }
        case .encryptedForCurrentVault(let items, let tags, let deleted, _, _, _, _):
            return await MainActor.run {
                guard let vaultID = self.vaultID else {
                    return false
                }
                let reboundTags = tags.map { backupImportInteractor.rebindTag($0, forVault: vaultID) }
                return syncInteractor.syncAndApplyChanges(
                    from: items,
                    externalTags: reboundTags,
                    externalDeleted: deleted,
                    in: vaultID
                )
            }
        case .needsPassword:
            throw .needsPassword
        }
    }

    private static func encode(_ versioned: ExchangeVaultVersioned) throws -> Data {
        let encoder = JSONEncoder()
        switch versioned {
        case .v1(let vault):
            return try encoder.encode(vault)
        case .v2(let vault):
            return try encoder.encode(vault)
        }
    }

    // MARK: - BackupSyncConfigStore

    func loadConfigs() -> [BackupConfig] {
        mainRepository.loadBackupConfigs()
    }

    func saveConfigs(_ configs: [BackupConfig]) {
        mainRepository.saveBackupConfigs(configs)
    }

    // MARK: - BackupSyncDateStore

    func lastSyncDate(for id: BackupConfig.ID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    func setLastSyncDate(_ date: Date, for id: BackupConfig.ID, consumed: BackupSyncFlags) {
        var dates = mainRepository.loadLastSyncDates()
        dates[id] = date
        mainRepository.saveLastSyncDates(dates)
        if consumed.overwritingVault {
            mainRepository.clearVaultOverrideAwaiting(configID: id)
        }
        if consumed.allowingAnyDeviceId {
            mainRepository.clearDeviceRegistrationAwaiting(configID: id)
        }
    }

    // MARK: - BackupAwaitingFlagsStoring

    var vaultOverrideAwaitingConfigIDs: Set<BackupConfig.ID> {
        mainRepository.vaultOverrideAwaitingConfigIDs
    }

    func markVaultOverrideAwaiting(configIDs: Set<BackupConfig.ID>) {
        mainRepository.markVaultOverrideAwaiting(configIDs: configIDs)
    }

    var deviceRegistrationAwaitingConfigIDs: Set<BackupConfig.ID> {
        mainRepository.deviceRegistrationAwaitingConfigIDs
    }

    func markDeviceRegistrationAwaiting(configIDs: Set<BackupConfig.ID>) {
        mainRepository.markDeviceRegistrationAwaiting(configIDs: configIDs)
    }
}
