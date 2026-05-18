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

    /// Marks every registered backend for vault overwrite on its next sync, then either
    /// triggers a fresh `syncAll` (no in-flight sync) or cancels the in-flight one and
    /// retries once it idles. The container resolves "all configs" itself, so this method
    /// has no opinion on the registered set — it just signals "next sync should overwrite,
    /// across the board." Each backend's `performSync` decides per-kind whether to honor
    /// the flag, and `BackupSyncAdapter` clears each id only when the matching sync
    /// reported `consumed.overwritingVault`.
    private func scheduleBackupSyncAfterPasswordChange() {
        // Fire-and-forget cancel/wait/mark/retry. Captures only `syncTriggerInteractor`
        // (app-lifetime) — no `self` retention, no instance state.
        Task { @MainActor [syncTriggerInteractor] in
            if syncTriggerInteractor.currentActivity.isRunning {
                // Cancel the in-flight sync — it captured pre-password-change providers and is
                // pushing stale-encryption data we need to overwrite. Then await the activity
                // transition to idle before marking and retrying.
                syncTriggerInteractor.cancelCurrentSync()
                for await _ in syncTriggerInteractor.syncEvents() {
                    if !syncTriggerInteractor.currentActivity.isRunning { break }
                }
            }
            // Mark AFTER the prior sync (if any) has finished/cancelled. If we marked
            // synchronously before spawning the Task, a sync from a previous password
            // change could complete successfully and consume the shared flag before our
            // syncAll() runs — leaving our sync without the overwrite flag set and
            // causing a merge attempt against a vault encrypted under the old key.
            syncTriggerInteractor.markAllServicesAwaitingVaultOverride()
            _ = try? await syncTriggerInteractor.syncAll()
        }
    }
}
