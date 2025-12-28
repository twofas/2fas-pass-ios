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
    private let webDAVBackupInteractor: WebDAVBackupInteracting
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
        webDAVBackupInteractor: WebDAVBackupInteracting
    ) {
        self.kind = kind
        self.itemsImportInteractor = itemsImportInteractor
        self.startupInteractor = startupInteractor
        self.importInteractor = importInteractor
        self.cloudSyncInteractor = cloudSyncInteractor
        self.onboardingInteractor = onboardingInteractor
        self.webDAVBackupInteractor = webDAVBackupInteractor
        notificationCenter = .default
        notificationCenter.addObserver(self, selector: #selector(stateChanged), name: .cloudStateChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didSync), name: .cloudDidSync, object: nil)
        notificationCenter.addObserver(self, selector: #selector(webDAVStateChanged), name: .webDAVStateChange, object: nil)
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
            case .file(let exchangeVault):
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
            case .file(let exchangeVault):
                importInteractor.extractItemsUsingMasterKey(masterKey, exchangeVault: exchangeVault) { [weak self] result in
                    switch result {
                    case .success((let items, let tags, let deletedItems)):
                        Log("VaultRecoveryRecoverModuleInteractor - items: \(items.count), deleted: \(deletedItems.count)", module: .moduleInteractor)
                        self?.itemsImportInteractor.importDeleted(deletedItems)
                        self?.itemsImportInteractor.importItems(items, tags: tags, completion: { count in
                            if count == items.count {
                                if self?.webDAVBackupInteractor.hasConfiguration == true {
                                    self?.syncCompletion = completion
                                    self?.webDAVBackupInteractor.sync()
                                } else {
                                    completion(true)
                                }
                            } else {
                                completion(false)
                            }
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
    
    @objc
    func webDAVStateChanged(_ notification: Notification) {
        guard let state = notification.userInfo?[Notification.webDAVState] as? WebDAVState else {
            return
        }
        
        switch state {
        case .synced:
            syncCompletion?(true)
            syncCompletion = nil
        case .error:
            syncCompletion?(false)
            syncCompletion = nil
        default:
            break
        }
    }
    
    func finish() {
        onboardingInteractor.finishVaultRecovery()
    }
}
