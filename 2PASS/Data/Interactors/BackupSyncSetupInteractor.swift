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
    /// `MainRepositoryImpl.init`) with its production collaborators via
    /// `BackupSyncContainer.setup(...)`. Idempotent: calling more than once re-runs
    /// `setup`, which atomically replaces the providers.
    func initialize()
}

/// Wires the app-lifetime `BackupSyncContainer` after construction.
///
/// `MainRepositoryImpl` owns the container as a `let` stored property and creates it inert
/// via `BackupSyncContainer()` in its own init. This interactor — which has access to the
/// `Export` / `BackupImport` / `Sync` interactors needed to build the adapter — finishes
/// the job by calling `BackupSyncContainer.setup(...)` on the existing instance. Two-phase
/// init resolves the cycle: the data layer holds the container without needing its
/// dependencies, and this upper layer supplies the dependencies without owning the
/// container.
///
/// `BackupSyncAdapter` is the single bridge from the new sync stack into the existing data
/// layer — it conforms to `BackupSyncContext`, `BackupVaultExporting`, `BackupLocalMerging`,
/// AND `BackupSyncConfigStore`. The container takes the same adapter instance for every
/// collaborator slot.
final class BackupSyncSetupInteractor: BackupSyncInstalling {
    private let mainRepository: MainRepository
    private let exportInteractor: ExportInteracting
    private let backupImportInteractor: BackupImportInteracting
    private let syncInteractor: SyncInteracting

    init(
        mainRepository: MainRepository,
        exportInteractor: ExportInteracting,
        backupImportInteractor: BackupImportInteracting,
        syncInteractor: SyncInteracting
    ) {
        self.mainRepository = mainRepository
        self.exportInteractor = exportInteractor
        self.backupImportInteractor = backupImportInteractor
        self.syncInteractor = syncInteractor
    }

    func initialize() {
        let adapter = BackupSyncAdapter(
            mainRepository: mainRepository,
            exportInteractor: exportInteractor,
            backupImportInteractor: backupImportInteractor,
            syncInteractor: syncInteractor
        )
        // The adapter satisfies all four collaborator protocols, so a single instance fills
        // every container slot. `cloudSync` comes straight from `MainRepository` — the
        // container materializes `CloudSyncAdapter` over it for any registered iCloud entry.
        mainRepository.backupSyncContainer.setup(
            configStore: adapter,
            dateStore: adapter,
            context: adapter,
            vaultExporter: adapter,
            localMerger: adapter,
            cloudSync: mainRepository.cloudSync
        )
    }
}
