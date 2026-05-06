// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

public protocol BackupSyncInstalling: AnyObject {
    /// Wires the existing `MainRepository.backupSyncContainer` (constructed inert by
    /// `MainRepositoryImpl.init`) with its production collaborators and per-vault
    /// `CloudSync` configuration via `BackupSyncContainer.setup(...)`. Idempotent: calling
    /// more than once re-runs `setup`, which atomically replaces the providers and
    /// re-applies the CloudSync chain — the supported re-apply path used by vault recovery
    /// after the recovered vault becomes the selected one.
    ///
    /// The "vault data is authoritative" signal that vault recovery used to carry via a
    /// `takingOverVault:` argument is now expressed through
    /// `BackupSyncContainer.markAllConfigsAwaitingVaultOverride()` — a unified per-config
    /// flag the next sync honors via `CloudSyncAdapter.performSync(overwritingVault:)`. The
    /// recovery flow marks that flag separately, then triggers the sync; `initialize()`
    /// stays a single no-arg entry point.
    func initialize()
}

/// Wires the app-lifetime `BackupSyncContainer` after construction.
///
/// `MainRepositoryImpl` owns the container as a `let` stored property and creates it inert
/// via `BackupSyncContainer()` in its own init. This interactor — which has access to the
/// `Export` / `BackupImport` / `Sync` interactors needed to build the adapter, plus the
/// `Items` / `DeletedItems` / `Tag` interactors needed to construct the `LocalStorage` /
/// `CloudCacheStorage` / `EncryptionHandler` for `CloudSync`'s per-vault setup — finishes
/// the job by calling `BackupSyncContainer.setup(...)` on the existing instance. Two-phase
/// init resolves the cycle: the data layer holds the container without needing its
/// dependencies, and this upper layer supplies the dependencies without owning the
/// container.
///
/// `BackupSyncAdapter` is the single bridge from the new sync stack into the existing data
/// layer — it conforms to `BackupSyncContext`, `BackupVaultExporting`, `BackupLocalMerging`,
/// AND `BackupSyncConfigStore`. The container takes the same adapter instance for every
/// collaborator slot. The runtime values CloudSync's setup chain needs (deviceID, vaultID,
/// multi-device-sync entitlement) are read by the container from the `BackupSyncContext`
/// the adapter exposes — the adapter forwards each to `MainRepository`, so this interactor
/// doesn't plumb them as separate arguments.
final class BackupSyncSetupInteractor: BackupSyncInstalling {
    private let mainRepository: MainRepository
    private let exportInteractor: ExportInteracting
    private let backupImportInteractor: BackupImportInteracting
    private let syncInteractor: SyncInteracting
    private let itemsInteractor: ItemsInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let tagInteractor: TagInteracting

    init(
        mainRepository: MainRepository,
        exportInteractor: ExportInteracting,
        backupImportInteractor: BackupImportInteracting,
        syncInteractor: SyncInteracting,
        itemsInteractor: ItemsInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        tagInteractor: TagInteracting
    ) {
        self.mainRepository = mainRepository
        self.exportInteractor = exportInteractor
        self.backupImportInteractor = backupImportInteractor
        self.syncInteractor = syncInteractor
        self.itemsInteractor = itemsInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.tagInteractor = tagInteractor
    }

    func initialize() {
        let adapter = BackupSyncAdapter(
            mainRepository: mainRepository,
            exportInteractor: exportInteractor,
            backupImportInteractor: backupImportInteractor,
            syncInteractor: syncInteractor
        )
        let cloudCacheStorage = CloudCacheStorageImpl(mainRepository: mainRepository)
        let encryptionHandler = EncryptionHandlerImpl(
            mainRepository: mainRepository,
            itemsInteractor: itemsInteractor,
            tagInteractor: tagInteractor
        )
        let localStorage = LocalStorageImpl(
            itemsInteractor: itemsInteractor,
            deletedItemsInteractor: deletedItemsInteractor,
            tagInteractor: tagInteractor,
            mainRepository: mainRepository
        )
        mainRepository.backupSyncContainer.setup(
            configStore: adapter,
            dateStore: adapter,
            context: adapter,
            vaultExporter: adapter,
            localMerger: adapter,
            awaitingFlags: adapter,
            localStorage: localStorage,
            cloudCacheStorage: cloudCacheStorage,
            encryptionHandler: encryptionHandler,
            currentDate: mainRepository.currentDate
        )
    }
}
