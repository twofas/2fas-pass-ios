// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol ChangePasswordInteracting: AnyObject {
    var isBiometryAvailable: Bool { get }
    func changeMasterPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping () -> Void
    )
}

final class ChangePasswordInteractor {
    private let biometryInteractor: BiometryInteracting
    private let itemsInteractor: ItemsInteracting
    private let protectionInteractor: ProtectionInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting

    init(
        biometryInteractor: BiometryInteracting,
        itemsInteractor: ItemsInteracting,
        protectionInteractor: ProtectionInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting
    ) {
        self.biometryInteractor = biometryInteractor
        self.itemsInteractor = itemsInteractor
        self.protectionInteractor = protectionInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
    }
}

extension ChangePasswordInteractor: ChangePasswordInteracting {
    var isBiometryAvailable: Bool {
        biometryInteractor.isBiometryAvailable
    }

    func changeMasterPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping () -> Void
    ) {
        let (current, tags) = itemsInteractor.getCompleteDecryptedList()
        let enableBiometryLogin = biometryInteractor.canUseBiometryForLogin
        Log(
            "ChangePasswordInteractor: Changing Master Password. Enable biometry: \(enableBiometryLogin)",
            module: .interactor
        )
        if protectionInteractor.salt == nil {
            Log("ChangePasswordInteractor: Restoring encryption data before password change", module: .interactor)
            protectionInteractor.restoreEntropy()
            protectionInteractor.createSeed()
            protectionInteractor.createSalt()
        }
        protectionInteractor.setMasterKey(for: masterPassword)
        guard protectionInteractor.masterKey != nil else {
            Log(
                "ChangePasswordInteractor: Can't derive Master Key - aborting password change",
                module: .interactor,
                severity: .error
            )
            completion()
            return
        }
        protectionInteractor.setShouldRetainEncryptionDataAfterLogin(true)
        biometryInteractor.setBiometryEnabled(enableBiometryLogin) { [weak self] result in
            if enableBiometryLogin && !result {
                Log(
                    "ChangePasswordInteractor: Re-encrypting Master Key for biometry failed - disabling biometry",
                    module: .interactor,
                    severity: .error
                )
                self?.biometryInteractor.setBiometryEnabled(false) { _ in }
            }
            self?.protectionInteractor.saveEncryptionReference()
            self?.protectionInteractor.updateExistingVault()
            self?.protectionInteractor.setupKeys()
            self?.itemsInteractor.reencryptDecryptedList(current, tags: tags, completion: { _ in
                Log("ChangePasswordInteractor - password was changed", module: .interactor)
                NotificationCenter.default.post(name: .passwordWasChanged, object: nil)
                self?.scheduleBackupSyncAfterPasswordChange()
                completion()
            })
        }
    }

    private func scheduleBackupSyncAfterPasswordChange() {
        Task { @MainActor [syncTriggerInteractor] in
            if syncTriggerInteractor.currentActivity.isRunning {
                syncTriggerInteractor.cancelCurrentSync()
                for await _ in syncTriggerInteractor.syncEvents() {
                    if !syncTriggerInteractor.currentActivity.isRunning { break }
                }
            }
            syncTriggerInteractor.markAllServicesAwaitingVaultOverride()
            _ = try? await syncTriggerInteractor.syncAll()
        }
    }
}
