// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os
import Data
import Common
import Backup

@MainActor
protocol VaultRecoveryRecoverModuleInteracting: AnyObject {
    var kind: VaultRecoveryRecoverKind { get }
    func recover() async -> Bool
    func finish()
}

@MainActor
final class VaultRecoveryRecoverModuleInteractor {
    let kind: VaultRecoveryRecoverKind
    private let itemsImportInteractor: ItemsImportInteracting
    private let startupInteractor: StartupInteracting
    private let importInteractor: ImportInteracting
    private let onboardingInteractor: OnboardingInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let configsInteractor: BackupSyncConfigsInteracting
    private let cacheInteractor: VaultRecoveryCacheInteracting

    private let syncAwaitSeconds = 60

    init(
        kind: VaultRecoveryRecoverKind,
        itemsImportInteractor: ItemsImportInteracting,
        startupInteractor: StartupInteracting,
        importInteractor: ImportInteracting,
        onboardingInteractor: OnboardingInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        configsInteractor: BackupSyncConfigsInteracting,
        cacheInteractor: VaultRecoveryCacheInteracting
    ) {
        self.kind = kind
        self.itemsImportInteractor = itemsImportInteractor
        self.startupInteractor = startupInteractor
        self.importInteractor = importInteractor
        self.onboardingInteractor = onboardingInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
        self.configsInteractor = configsInteractor
        self.cacheInteractor = cacheInteractor
    }
}

extension VaultRecoveryRecoverModuleInteractor: VaultRecoveryRecoverModuleInteracting {
    func recover() async -> Bool {
        switch kind {
        case .importUnencrypted(let items, let tags):
            let count = await importItems(items, tags: tags)
            return count == items.count

        case .recoverEncrypted(let entropy, let masterKey, let recoveryData):
            if case .localVault = recoveryData {
                return await startupInteractor.restoreVault(entropy: entropy, masterKey: masterKey)
            }

            startupInteractor.setEntropy(entropy, masterKey: masterKey)
            let vaultID: VaultID
            let creationDate: Date?
            let modificationDate: Date
            let reference: String
            switch recoveryData {
            case .file(let exchangeVault, _):
                let vaultIDString = exchangeVault.vault.id
                guard let vaultIDValue = VaultID(uuidString: vaultIDString),
                      let referenceValue = exchangeVault.encryption?.reference else {
                    return false
                }
                vaultID = vaultIDValue
                creationDate = exchangeVault.vault.createdAt.map { Date.init(exportTimestamp: $0) }
                modificationDate = Date(exportTimestamp: exchangeVault.vault.updatedAt)
                reference = referenceValue
            case .cloud(let vaultRawData):
                vaultID = vaultRawData.vaultID
                creationDate = vaultRawData.createdAt
                modificationDate = vaultRawData.updatedAt
                reference = vaultRawData.reference
            case .localVault:
                fatalError()
            }

            switch importInteractor.validateReference(reference, using: masterKey, for: vaultID) {
            case .success: break
            case .failure(let error):
                Log("VaultRecoveryRecoverModuleInteractor - error while validating reference: \(error)")
                return false
            }

            guard startupInteractor.createVault(for: vaultID, creationDate: creationDate, modificationDate: modificationDate) else {
                return false
            }

            startupInteractor.clearAfterInit()

            switch recoveryData {
            case .file(let exchangeVault, let source):
                let extracted = await extractItems(masterKey: masterKey, exchangeVault: exchangeVault)
                switch extracted {
                case .success((let items, let tags, let deletedItems)):
                    Log("VaultRecoveryRecoverModuleInteractor - items: \(items.count), deleted: \(deletedItems.count)", module: .moduleInteractor)
                    itemsImportInteractor.importDeleted(deletedItems)
                    let count = await importItems(items, tags: tags)
                    guard count == items.count else { return false }
                    guard let configID = persistRecoverySource(source) else { return true }
                    return await performRecoverySync(configID: configID)
                case .failure(let error):
                    Log("Error while extracting items during Vault Recovery, error: \(error)")
                    return false
                }
            case .cloud:
                return await performRecoveryCloudSync()
            case .localVault:
                fatalError()
            }
        }
    }

    private func persistRecoverySource(_ source: VaultRecoveryFileSource) -> BackupConfig.ID? {
        switch source {
        case .webDAV:
            guard let config = cacheInteractor.cachedWebDAVConfig
            else { return nil }
            
            let id = configsInteractor.addWebDAVConfig(config)
            syncTriggerInteractor.markAwaitingDeviceRegistration(configID: id)

            cacheInteractor.clearCachedConfigs()
            return id
        case .s3:
            guard let config = cacheInteractor.cachedS3Config
            else { return nil }
            
            let id = configsInteractor.addS3Config(config)
            syncTriggerInteractor.markAwaitingDeviceRegistration(configID: id)
            cacheInteractor.clearCachedConfigs()
            return id
        case .localFile:
            return nil
        }
    }

    private func performRecoverySync(configID: BackupConfig.ID) async -> Bool {
        do {
            try await syncTriggerInteractor.sync(id: configID)
            return true
        } catch {
            return false
        }
    }

    private func importItems(_ items: [ItemData], tags: [ItemTagData]) async -> Int {
        await withCheckedContinuation { continuation in
            itemsImportInteractor.importItems(items, tags: tags) { count in
                continuation.resume(returning: count)
            }
        }
    }

    private func extractItems(
        masterKey: MasterKey,
        exchangeVault: ExchangeVaultVersioned
    ) async -> Result<([ItemData], [ItemTagData], [DeletedItemData]), ImportExtractMasterPasswordEncryptionError> {
        await withCheckedContinuation { continuation in
            importInteractor.extractItemsUsingMasterKey(masterKey, exchangeVault: exchangeVault) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func performRecoveryCloudSync() async -> Bool {
        guard let iCloudID = resolveiCloudConfigID() else { return true }

        cacheInteractor.clearCachedConfigs()
        syncTriggerInteractor.markAwaitingDeviceRegistration(configID: iCloudID)

        let timer = Task {
            try? await Task.sleep(for: .seconds(syncAwaitSeconds))
        }

        Task.detached { [syncTriggerInteractor, timer] in
            do {
                try await syncTriggerInteractor.sync(id: iCloudID)
            } catch {
                Log("VaultRecoveryRecoverModuleInteractor - iCloud sync failed: \(error)", module: .moduleInteractor)
            }
            timer.cancel()
        }

        await timer.value

        if !timer.isCancelled {
            Log("VaultRecoveryRecoverModuleInteractor - iCloud sync timed out; continuing recovery", module: .moduleInteractor)
        }
        return true
    }

    private func resolveiCloudConfigID() -> BackupConfig.ID? {
        let iCloudID = configsInteractor.addiCloudConfig() ?? configsInteractor.allConfigs.iCloudEntry?.id
        guard let iCloudID else { return nil }
        return iCloudID
    }

    func finish() {
        onboardingInteractor.finishVaultRecovery()
    }
}
