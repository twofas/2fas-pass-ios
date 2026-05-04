// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os
import Data
import Common

protocol VaultRecoveryRecoverModuleInteracting: AnyObject {
    var kind: VaultRecoveryRecoverKind { get }
    func recover() async -> Bool
    func finish()
}

final class VaultRecoveryRecoverModuleInteractor {
    let kind: VaultRecoveryRecoverKind
    private let itemsImportInteractor: ItemsImportInteracting
    private let startupInteractor: StartupInteracting
    private let importInteractor: ImportInteracting
    private let cloudSyncInteractor: CloudSyncInteracting
    private let onboardingInteractor: OnboardingInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let configsInteractor: BackupSyncConfigsInteracting
    private let notificationCenter: NotificationCenter

    private let syncAwaitSeconds = 60

    private var syncCompletion: ((Bool) -> Void)?

    init(
        kind: VaultRecoveryRecoverKind,
        itemsImportInteractor: ItemsImportInteracting,
        startupInteractor: StartupInteracting,
        importInteractor: ImportInteracting,
        cloudSyncInteractor: CloudSyncInteracting,
        onboardingInteractor: OnboardingInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        configsInteractor: BackupSyncConfigsInteracting
    ) {
        self.kind = kind
        self.itemsImportInteractor = itemsImportInteractor
        self.startupInteractor = startupInteractor
        self.importInteractor = importInteractor
        self.cloudSyncInteractor = cloudSyncInteractor
        self.onboardingInteractor = onboardingInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
        self.configsInteractor = configsInteractor
        notificationCenter = .default
        notificationCenter.addObserver(self, selector: #selector(stateChanged), name: .cloudStateChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didSync), name: .cloudDidSync, object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self)
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
                    // Persist the source-of-truth config NOW — items are committed to local
                    // storage, so the credentials match a vault we successfully decrypted and
                    // imported. (Earlier the persistence happened on `fetchVault` success,
                    // which leaked credentials whenever recovery was aborted between fetch
                    // and import.)
                    guard let configID = persistRecoverySource(source) else { return true }
                    return await performRecoverySync(configID: configID)
                case .failure(let error):
                    Log("Error while extracting items during Vault Recovery, error: \(error)")
                    return false
                }
            case .cloud:
                return await awaitCloudSync()
            case .localVault:
                fatalError()
            }
        }
    }
    
    @objc
    func stateChanged() {
        if cloudSyncInteractor.currentState == .disabled {
            cloudSyncInteractor.enable()
            cloudSyncInteractor.synchronize()
        }
    }
    
    @objc
    func didSync() {
        guard let syncCompletion else { return }
        syncCompletion(true)
        self.syncCompletion = nil
        return
    }

    /// Persists the recovery's source-of-truth config (e.g. the WebDAV credentials the user
    /// entered to fetch this vault). Called *only* after a successful item import — the
    /// guarantee being: a config record exists in `MainRepository.loadBackupConfigs` only
    /// for backends whose vaults are actually decrypted and stored locally. Returns the
    /// new config's id so the caller can drive the immediate post-recovery sync without
    /// re-querying; `nil` means "nothing further to sync" (e.g. local-file recovery).
    private func persistRecoverySource(_ source: VaultRecoveryFileSource) -> UUID? {
        switch source {
        case .webDAV(let config):
            // Persist the config and mark it as needing first-sync device-id registration.
            // The flag drives `allowingAnyDeviceId: true` on every sync (this immediate
            // `performRecoverySync` AND any future retry — routine, per-row, etc.) until
            // the first successful sync clears it via `BackupSyncAdapter.setLastSyncDate`.
            // Closes the regression where a transient post-recovery sync failure left
            // routine syncs permanently broken on the multi-device-id gate.
            let id = configsInteractor.addWebDAVConfig(config)
            syncTriggerInteractor.markAwaitingDeviceRegistration(configID: id)
            return id
        case .localFile:
            return nil
        }
    }

    /// Kick off a recovery sync against the just-persisted WebDAV config through the
    /// `BackupSyncContainer`. The `allowingAnyDeviceId: true` behavior — needed because
    /// recovery's whole point is "this vault used to live somewhere else" — comes for free
    /// from the `markAwaitingDeviceRegistration(configID:)` mark issued in
    /// `persistRecoverySource`; the container ORs it into the per-id closure inside
    /// `sync(_:)`.
    private func performRecoverySync(configID: UUID) async -> Bool {
        do {
            try await syncTriggerInteractor.sync(id: configID)
            // Returns silently on success OR when no service matched / container not set
            // up — both treated as a soft success so recovery doesn't get stuck on edge
            // cases (the no-service path "shouldn't happen" since we just resolved an id).
            return true
        } catch {
            // Sync failure or debounce (.cancelled) — recovery treats both as needing
            // user attention.
            return false
        }
    }

    /// Bridges the completion-handler `ItemsImportInteractor.importItems` into Swift
    /// Concurrency. The completion is invoked exactly once by the importer, so a
    /// `withCheckedContinuation` wrapper is safe.
    private func importItems(_ items: [ItemData], tags: [ItemTagData]) async -> Int {
        await withCheckedContinuation { continuation in
            itemsImportInteractor.importItems(items, tags: tags) { count in
                continuation.resume(returning: count)
            }
        }
    }

    /// Bridges the queue-based `ImportInteractor.extractItemsUsingMasterKey` into Swift
    /// Concurrency. The completion fires once on the importer's internal queue, which is
    /// fine for `withCheckedContinuation` — the resumption hops back to the caller's
    /// executor automatically.
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

    /// Wait for the cloud sync triggered by `cloudSyncInteractor.setup(takeoverVault:)`
    /// to finish — or for the timeout to fire. Two paths can resume the continuation:
    /// the `@objc didSync` notification handler invokes `syncCompletion(true)`, and the
    /// timeout Task calls `resumeOnce(true)` directly. The lock is the single-fire gate
    /// (`didSync`'s own `guard let syncCompletion` only protects the notification path
    /// once the direct timeout path bypasses self).
    private func awaitCloudSync() async -> Bool {
        let timeoutSeconds = syncAwaitSeconds
        return await withCheckedContinuation { continuation in
            let resumed = OSAllocatedUnfairLock(initialState: false)
            let resumeOnce: @Sendable (Bool) -> Void = { result in
                let shouldResume = resumed.withLock { fired in
                    guard !fired else { return false }
                    fired = true
                    return true
                }
                if shouldResume {
                    continuation.resume(returning: result)
                }
            }
            syncCompletion = { result in resumeOnce(result) }
            cloudSyncInteractor.setup(takeoverVault: true)
            // timeout for awaiting the start of synchronization
            Task {
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                resumeOnce(true)
            }
        }
    }

    func finish() {
        onboardingInteractor.finishVaultRecovery()
    }
}
