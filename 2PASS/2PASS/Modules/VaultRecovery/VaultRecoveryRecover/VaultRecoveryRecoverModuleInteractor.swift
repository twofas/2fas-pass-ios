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
                return await performRecoveryCloudSync()
            case .localVault:
                fatalError()
            }
        }
    }
    
    /// Persists the recovery's source-of-truth config (e.g. the WebDAV credentials the user
    /// entered to fetch this vault). Called *only* after a successful item import — the
    /// guarantee being: a config record exists in `MainRepository.loadBackupConfigs` only
    /// for backends whose vaults are actually decrypted and stored locally. Returns the
    /// new config's id so the caller can drive the immediate post-recovery sync without
    /// re-querying; `nil` means "nothing further to sync" (e.g. local-file recovery).
    private func persistRecoverySource(_ source: VaultRecoveryFileSource) -> UUID? {
        switch source {
        case .webDAV:
            // The source enum is tag-only: it tells us which recovery cache slot to read.
            // The cache interactor owns the JSON + encrypt-at-rest pipeline internally
            // (same shape as `saveBackupConfigs`), so `cachedWebDAVConfig` returns the
            // typed `BackupWebDAVConfig?` directly. `nil` means the cache was wiped between
            // vault-pick and persist — shouldn't happen in practice; treat as
            // `.localFile` and skip post-recovery sync.
            guard let config = cacheInteractor.cachedWebDAVConfig
            else { return nil }
            // Persist the config and mark it as needing first-sync device-id registration.
            // The flag drives `allowingAnyDeviceId: true` on every sync (this immediate
            // `performRecoverySync` AND any future retry — routine, per-row, etc.) until
            // the first successful sync clears it via `BackupSyncAdapter.setLastSyncDate`.
            // Closes the regression where a transient post-recovery sync failure left
            // routine syncs permanently broken on the multi-device-id gate.
            let id = configsInteractor.addWebDAVConfig(config)
            syncTriggerInteractor.markAwaitingDeviceRegistration(configID: id)
            // Config is now on disk (encrypted under saveBackupConfigs) — the in-memory
            // recovery cache is redundant. Wipe both source slots; the user may have explored
            // both S3 and WebDAV in the same session, and once any recovery commits to disk
            // the other slot is stale too.
            cacheInteractor.clearCachedConfigs()
            return id
        case .s3:
            guard let config = cacheInteractor.cachedS3Config
            else { return nil }
            // Same registration shape as WebDAV — file-based backends share the
            // post-recovery `awaitingDeviceRegistration` handshake. The first successful
            // sync clears the flag via `BackupSyncAdapter.setLastSyncDate`.
            let id = configsInteractor.addS3Config(config)
            syncTriggerInteractor.markAwaitingDeviceRegistration(configID: id)
            cacheInteractor.clearCachedConfigs()
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

    /// Wait for the post-recovery iCloud sync to finish — or for the timeout to fire.
    ///
    /// Three steps: (1) ensure an iCloud config exists — adds it (driving `cloudSync.enable()`
    /// via the container's `saveConfigs(_:)` diff) if missing, or reuses the existing entry.
    /// (2) Mark the iCloud config as awaiting device registration — the per-config "next sync
    /// is allowed to register a new deviceID against this vault" flag, honored by
    /// `CloudSyncAdapter.performSync` via `cloudSync.syncOnce(allowingAnyDeviceId:)` which
    /// arms `setTakingOverVault(true)` and bypasses `MergeHandler`'s deviceID mismatch gate.
    /// (3) Race a timer Task against the actual
    /// `sync(id:)`: whichever completes first unblocks the await. **Sync is never cancelled**
    /// — it runs in a `Task.detached` that deliberately outlives this function, so when the
    /// timer elapses naturally we let recovery proceed to the main screen while iCloud keeps
    /// running in the background. When sync finishes first, it calls `timer.cancel()`, which
    /// throws inside `Task.sleep` and unblocks `await timer.value` immediately;
    /// `timer.isCancelled` then distinguishes the success path from the timeout path.
    ///
    /// No explicit `BackupSyncSetupInteractor.initialize()` re-run is needed. The vault id
    /// is read pull-style from `BackupSyncContext.vaultID` inside `CloudHandler.sync()` —
    /// `createVault → selectVault` (which ran before `performRecoveryCloudSync()` is called) updated
    /// `MainRepository.selectedVault`, so the `sync(id:)` call below picks up the recovered
    /// vault id automatically.
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

    private func resolveiCloudConfigID() -> UUID? {
        let iCloudID = configsInteractor.addiCloudConfig() ?? configsInteractor.allConfigs.iCloudEntry?.id
        guard let iCloudID else { return nil }
        return iCloudID
    }

    func finish() {
        onboardingInteractor.finishVaultRecovery()
    }
}
