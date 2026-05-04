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
    private let configsInteractor: BackupSyncConfigsInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting

    init(
        biometryInteractor: BiometryInteracting,
        itemsInteractor: ItemsInteracting,
        protectionInteractor: ProtectionInteracting,
        configsInteractor: BackupSyncConfigsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting
    ) {
        self.biometryInteractor = biometryInteractor
        self.itemsInteractor = itemsInteractor
        self.protectionInteractor = protectionInteractor
        self.configsInteractor = configsInteractor
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
        protectionInteractor.setMasterKey(for: masterPassword)
        biometryInteractor.setBiometryEnabled(enableBiometryLogin) { [weak self] result in
            self?.protectionInteractor.saveEncryptionReference()
            self?.protectionInteractor.updateExistingVault()
            self?.protectionInteractor.setupKeys()
            self?.itemsInteractor.reencryptDecryptedList(current, tags: tags, completion: { _ in
                Log("ChangePasswordInteractor - password was changed", module: .interactor)
                // `.passwordWasChanged` is still observed by `CloudHandler.setPasswordWasChanged`
                // for the iCloud merge flag — keep posting it. The backup-sync side effect
                // used to live on `MainModuleInteractor` as a second observer of the same
                // notification; it's now inlined below so cause and effect are co-located.
                NotificationCenter.default.post(name: .passwordWasChanged, object: nil)
                self?.scheduleBackupSyncAfterPasswordChange()
                completion()
            })
        }
    }

    /// Marks every file-based backend for vault overwrite on its next sync, then either
    /// triggers a fresh `syncAll` (no in-flight sync) or cancels the in-flight one and
    /// retries once it idles. iCloud is intentionally excluded — its re-encryption flows
    /// through `CloudHandler` via the `.passwordWasChanged` observer above.
    ///
    /// Per-id (rather than a single Bool) is what guarantees that with multiple file-based
    /// backends, *every* one re-pushes the freshly re-encrypted vault — not just whichever
    /// one syncs first.
    private func scheduleBackupSyncAfterPasswordChange() {
        let fileServiceIDs: Set<UUID> = Set(
            configsInteractor.allConfigs
                .filter { $0.kind == .webDAV || $0.kind == .s3 }
                .map(\.id)
        )
        guard !fileServiceIDs.isEmpty else { return }
        syncTriggerInteractor.markVaultOverrideAwaiting(configIDs: fileServiceIDs)

        // Fire-and-forget cancel/wait/retry. The Bool that used to live on
        // `MainModuleInteractor` as `awaitsSyncRetryAfterPasswordChange` is gone; the wait
        // condition is now an async loop bound to this task's local frame. Captures only
        // `syncTriggerInteractor` (app-lifetime) — no `self` retention, no instance state.
        Task { @MainActor [syncTriggerInteractor] in
            if syncTriggerInteractor.currentActivity.isRunning {
                // Cancel the in-flight sync — it captured pre-password-change providers and is
                // pushing stale-encryption data we need to overwrite. Cancellation throws
                // inside `BackupFileSyncSession.performSync` before its success branch calls
                // `dateStore.setLastSyncDate(...)`, so the override flag we just marked
                // survives. Then await the activity transition to idle before retrying.
                syncTriggerInteractor.cancelCurrentSync()
                for await _ in syncTriggerInteractor.syncEvents() {
                    if !syncTriggerInteractor.currentActivity.isRunning { break }
                }
            }
            await syncTriggerInteractor.syncAll()
        }
    }
}
