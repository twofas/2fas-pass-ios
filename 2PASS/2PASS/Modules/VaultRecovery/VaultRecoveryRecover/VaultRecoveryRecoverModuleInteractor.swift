// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol VaultRecoveryRecoverModuleInteracting: AnyObject {
    var kind: VaultRecoveryRecoverKind { get }
    func recover(completion: @escaping (Bool) -> Void)
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
    func recover(completion: @escaping (Bool) -> Void) {
        switch kind {
        case .importUnencrypted(let items, let tags):
            itemsImportInteractor.importItems(items, tags: tags) { count in
                completion(count == items.count)
            }
        case .recoverEncrypted(let entropy, let masterKey, let recoveryData):
            if case .localVault = recoveryData {
                Task { @MainActor in
                    let result = await startupInteractor.restoreVault(entropy: entropy, masterKey: masterKey)
                    completion(result)
                }
                return
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
                    completion(false)
                    return
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
                completion(false)
                return
            }
    
            guard startupInteractor.createVault(for: vaultID, creationDate: creationDate, modificationDate: modificationDate) else {
                completion(false)
                return
            }
            
            startupInteractor.clearAfterInit()
            
            switch recoveryData {
            case .file(let exchangeVault, let source):
                importInteractor.extractItemsUsingMasterKey(masterKey, exchangeVault: exchangeVault) { [weak self] result in
                    switch result {
                    case .success((let items, let tags, let deletedItems)):
                        Log("VaultRecoveryRecoverModuleInteractor - items: \(items.count), deleted: \(deletedItems.count)", module: .moduleInteractor)
                        self?.itemsImportInteractor.importDeleted(deletedItems)
                        self?.itemsImportInteractor.importItems(items, tags: tags, completion: { [weak self] count in
                            guard count == items.count else {
                                completion(false)
                                return
                            }
                            // Persist the source-of-truth config NOW — items are committed to
                            // local storage, so the credentials match a vault we successfully
                            // decrypted and imported. The order matters: `runWebDAVRecoverySync`
                            // looks up by `kind == .webDAV` from `configsInteractor.allConfigs`,
                            // so the save must precede it. (Earlier the persistence happened on
                            // `fetchVault` success, which leaked credentials whenever recovery
                            // was aborted between fetch and import.)
                            self?.persistRecoverySource(source)
                            self?.runWebDAVRecoverySync(completion: completion)
                        })
                    case .failure(let error):
                        Log("Error while extracting items during Vault Recovery, error: \(error)")
                        completion(false)
                    }
                }
            case .cloud:
                syncCompletion = completion
                cloudSyncInteractor.setup(takeoverVault: true)
                // timeout for awaiting the start of synchronization
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(syncAwaitSeconds)) {
                    self.didSync()
                }
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
    /// for backends whose vaults are actually decrypted and stored locally. iCloud and the
    /// file-picker entry points pass `nil` and no-op here.
    private func persistRecoverySource(_ source: VaultRecoveryFileSource) {
        switch source {
        case .webDAV(let config):
            // Persist the config and mark it as needing first-sync device-id registration.
            // The flag drives `allowingAnyDeviceId: true` on every sync (this immediate
            // `runWebDAVRecoverySync` AND any future retry — routine, per-row, etc.) until
            // the first successful sync clears it via `BackupSyncAdapter.setLastSyncDate`.
            // Closes the regression where a transient post-recovery sync failure left
            // routine syncs permanently broken on the multi-device-id gate.
            let id = configsInteractor.addWebDAVConfig(config)
            syncTriggerInteractor.markDeviceRegistrationAwaiting(configIDs: [id])
        case .localFile:
            break
        }
    }

    /// If a WebDAV backend is configured, kick off a recovery sync against it through the new
    /// `BackupSyncContainer`. `allowingAnyDeviceId: true` lets the merge tolerate a vault that
    /// was created on a different device id even on a non-multi-device entitlement —
    /// recovery's whole point is "this vault used to live somewhere else." If no WebDAV
    /// backend is configured, recovery completes immediately.
    private func runWebDAVRecoverySync(completion: @escaping (Bool) -> Void) {
        guard let webDAVID = configsInteractor.allConfigs.first(where: { $0.kind == .webDAV })?.id else {
            completion(true)
            return
        }
        Task { [syncTriggerInteractor] in
            let result = await syncTriggerInteractor.sync(
                id: webDAVID,
                overwritingVault: false,
                allowingAnyDeviceId: true,
                onEvent: nil
            )
            // `nil` happens when no service matched (shouldn't, since we just resolved an id)
            // or the container hasn't been installed yet — treat both as a soft success so
            // recovery doesn't get stuck. `.cancelled` and other failures map to `false`.
            switch result {
            case .none, .success:
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }

    func finish() {
        onboardingInteractor.finishVaultRecovery()
    }
}
