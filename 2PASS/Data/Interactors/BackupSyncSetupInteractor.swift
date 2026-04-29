// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

public protocol BackupSyncInstalling: AnyObject {
    /// Builds the backup-sync stack and installs the resulting `BackupSyncContainer` into
    /// `MainRepository.backupSyncContainer`. Idempotent: calling more than once replaces the
    /// existing container. Intended to be invoked exactly once at app launch from
    /// `RootModuleInteractor.initializeApp()`.
    func initialize()
}

/// Composition-root interactor for the backup sync stack.
///
/// Resolves the layering tension that earlier surfaced when `MainRepositoryImpl.init` reached
/// up into `InteractorFactory`. The dependency direction here is honest: this upper-layer
/// interactor *builds* the container (it has access to the export/import/sync interactors)
/// and pushes it down into the data layer via `MainRepository.setBackupSyncContainer(_:)`.
/// The data layer thereby holds the container without knowing how to construct it.
///
/// `BackupSyncAdapter` is the single bridge from the new sync stack into the existing data
/// layer — it conforms to `BackupSyncContext`, `BackupVaultExporting`, `BackupLocalMerging`,
/// AND `BackupSyncConfigStore`. The container takes the same adapter instance for both the
/// factory's collaborators and its own configStore.
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
        let container = BackupSyncContainer(
            configStore: adapter,
            dateStore: adapter,
            context: adapter,
            vaultExporter: adapter,
            localMerger: adapter,
            cloudSync: mainRepository.cloudSync
        )

        mainRepository.setBackupSyncContainer(container)
    }
}
