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
    private let passwordImportInteractor: PasswordImportInteracting
    private let startupInteractor: StartupInteracting
    private let importInteractor: ImportInteracting
    private let cloudSyncInteractor: CloudSyncInteracting
    private let onboardingInteractor: OnboardingInteracting
    private let webDAVBackupInteractor: WebDAVBackupInteracting
    private let notificationCenter: NotificationCenter
    
    private let syncAwaitSeconds = 15
    
    private var syncCompletion: ((Bool) -> Void)?
    
    init(
        kind: VaultRecoveryRecoverKind,
        passwordImportInteractor: PasswordImportInteracting,
        startupInteractor: StartupInteracting,
        importInteractor: ImportInteracting,
        cloudSyncInteractor: CloudSyncInteracting,
        onboardingInteractor: OnboardingInteracting,
        webDAVBackupInteractor: WebDAVBackupInteracting
    ) {
        self.kind = kind
        self.passwordImportInteractor = passwordImportInteractor
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
        case .importUnencrypted(let passwords, let tags):
            passwordImportInteractor.importPasswords(passwords, tags: tags) { count in
                completion(count == passwords.count)
            }
        case .recoverEncrypted(let entropy, let masterKey, let recoveryData):
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
                importInteractor.extractPasswordsUsingMasterKey(masterKey, exchangeVault: exchangeVault) { [weak self] result in
                    switch result {
                    case .success((let passwords, let tags, let deletedItems)):
                        Log("VaultRecoveryRecoverModuleInteractor - passwords: \(passwords.count), deleted: \(deletedItems.count)", module: .moduleInteractor)
                        self?.passwordImportInteractor.importDeleted(deletedItems)
                        self?.passwordImportInteractor.importPasswords(passwords, tags: tags, completion: { count in
                            if count == passwords.count {
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
                        Log("Error while extracting passwords during Vault Recovery, error: \(error)")
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
            }
        }
    }
    
    @objc
    func stateChanged() {
        if cloudSyncInteractor.currentState == .disabledAvailable {
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
