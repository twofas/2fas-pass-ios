// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

/// User-driven sync trigger entry points ("Sync now" buttons, per-row sync), plus read access
/// to the per-config last-success timestamps that those triggers produce. Reads the installed
/// `BackupSyncContainer` off `MainRepository` and forwards. Lives apart from
/// `BackupSyncConfigsInteracting` so that callers needing only CRUD on configs don't transitively
/// depend on the orchestration surface — and vice versa.
///
/// `lastSyncDate(for:)` is on this protocol because the timestamp is an *output* of sync runs
/// (written by `BackupFileSyncSession` on success via the `BackupSyncDateStore` adapter) rather
/// than an input to the config CRUD surface.
///
/// All trigger entry points are no-ops when the container hasn't been installed yet
/// (`backupSyncSetupInteractor().initialize()` must have run first). The container is the optional
/// piece; the configs themselves are persisted in `MainRepository` and outlive any container
/// lifecycle.
public protocol BackupSyncTriggerInteracting: AnyObject {
    /// Live app-wide backup sync activity snapshot.
    var currentActivity: BackupSyncActivity { get }

    /// Runs every registered backend through the convergence loop. No-op if no container.
    ///
    /// `onEvent` (optional) receives per-service `started`/`finished` lifecycle events so the UI
    /// can reflect the coordinator's serial execution row-by-row instead of a global flag.
    /// Events fire from the coordinator actor; consumers running on the main actor must hop
    /// themselves (e.g. via `Task { @MainActor in ... }`).
    func syncAll(onEvent: BackupSyncSession.ProgressHandler?)

    /// Runs only the backend with the given id through the coordinator. No-op if no entry
    /// matches or the container hasn't been installed yet.
    func sync(id: UUID, onEvent: BackupSyncSession.ProgressHandler?) async

    /// Most recent successful sync timestamp for `id`, or `nil` if no successful sync recorded.
    /// Reads through to the persistent date store; intended for UI display ("Last synced …").
    func lastSyncDate(for id: UUID) -> Date?

    /// Cancels the currently running backup sync session, if any.
    func cancelCurrentSync()
}

public extension BackupSyncTriggerInteracting {
    func syncAll() { syncAll(onEvent: nil) }
    func sync(id: UUID) async { await sync(id: id, onEvent: nil) }
}

final class BackupSyncTriggerInteractor: BackupSyncTriggerInteracting {
    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }

    var currentActivity: BackupSyncActivity {
        mainRepository.backupSyncContainer?.currentActivity ?? .idle
    }

    func syncAll(onEvent: BackupSyncSession.ProgressHandler?) {
        mainRepository.backupSyncContainer?.syncAll(onEvent: onEvent)
    }

    func sync(id: UUID, onEvent: BackupSyncSession.ProgressHandler?) async {
        _ = await mainRepository.backupSyncContainer?.sync(id, onEvent: onEvent)
    }

    func lastSyncDate(for id: UUID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    func cancelCurrentSync() {
        mainRepository.backupSyncContainer?.cancelCurrentSync()
    }
}
