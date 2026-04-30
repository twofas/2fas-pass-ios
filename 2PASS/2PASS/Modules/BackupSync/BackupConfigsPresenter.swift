// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import SwiftUI
import Backup
import Common
import CommonUI
import Data

enum BackupConfigsDestination: RouterDestination {
    case addWebDAV
    case addS3
    case editWebDAV(configID: UUID)
    case editS3(configID: UUID)
    case removeConfirmation(name: String, onConfirm: Callback)

    var id: String {
        switch self {
        case .addWebDAV: "addWebDAV"
        case .addS3: "addS3"
        case .editWebDAV(let configID): "editWebDAV-\(configID)"
        case .editS3(let configID): "editS3-\(configID)"
        case .removeConfirmation(let name, _): "removeConfirmation-\(name)"
        }
    }
}

struct BackupConfigRowItem: Identifiable, Equatable {
    let id: UUID
    let kind: SyncServiceKind
    let title: String
    let subtitle: String?
    let statusText: String
    let isSyncing: Bool
    let icon: SettingsIcon
}

@Observable @MainActor
final class BackupConfigsPresenter {

    var destination: BackupConfigsDestination?
    private(set) var rows: [BackupConfigRowItem] = []
    private(set) var isSyncing: Bool = false

    /// IDs of configs the coordinator is *actively running right now*. Updated from per-service
    /// `started`/`finished` events emitted by `BackupSyncCoordinator`, so the UI reflects the
    /// coordinator's serial execution row-by-row instead of marking every config in flight for
    /// the whole `syncAll` run. iCloud rows derive their syncing state from
    /// `interactor.cloudState.isSyncing` because CloudKit owns its own state machine.
    private var syncingConfigIDs: Set<UUID> = []

    /// In-flight task spawned by `onSyncNow()`. Held so the user can cancel a running sync
    /// via the same button. Cancellation propagates through the coordinator's
    /// `withTaskCancellationHandler` to the in-flight service; queued services are skipped.
    private var syncAllTask: Task<Void, Never>?

    var isEmpty: Bool { rows.isEmpty }
    var canAddiCloud: Bool { !rows.contains { $0.kind == .iCloud } }

    private let interactor: BackupConfigsModuleInteracting

    init(interactor: BackupConfigsModuleInteracting) {
        self.interactor = interactor
        reload()
        interactor.cloudStateChanged = { [weak self] in
            Task { @MainActor in self?.reload() }
        }
    }

    func onAppear() {
        reload()
    }

    func onChooseProvider(_ kind: SyncServiceKind) {
        handleAddChoice(kind)
    }

    func onSelect(_ row: BackupConfigRowItem) {
        switch row.kind {
        case .webDAV:
            destination = .editWebDAV(configID: row.id)
        case .s3:
            destination = .editS3(configID: row.id)
        case .iCloud:
            break
        }
    }

    func onDelete(_ row: BackupConfigRowItem) {
        destination = .removeConfirmation(name: row.title, onConfirm: { [weak self] in
            guard let self else { return }
            self.interactor.remove(id: row.id, kind: row.kind)
            withAnimation { self.reload() }
        })
    }

    func onSyncNow() {
        guard !isSyncing else { return }
        isSyncing = true
        reload()
        syncAllTask = Task { [weak self] in
            await self?.interactor.syncAll(onEvent: Self.makeProgressForwarder(self))
            await MainActor.run {
                guard let self else { return }
                self.isSyncing = false
                // Defensive: clear any straggler ids the coordinator could not retire (e.g. if
                // its task was cancelled mid-`finished` emission).
                self.syncingConfigIDs.removeAll()
                self.syncAllTask = nil
                self.reload()
            }
        }
    }

    func onCancelSyncAll() {
        syncAllTask?.cancel()
    }

    func onSyncRow(_ row: BackupConfigRowItem) {
        guard !syncingConfigIDs.contains(row.id) else { return }
        Task { [weak self] in
            await self?.interactor.sync(id: row.id, onEvent: Self.makeProgressForwarder(self))
            await MainActor.run {
                // Defensive cleanup if the started/finished pair did not fire.
                self?.syncingConfigIDs.remove(row.id)
                self?.reload()
            }
        }
    }

    /// Builds a `@Sendable` closure that hops the coordinator's lifecycle events back to the
    /// main actor and updates `syncingConfigIDs`. Captures the presenter weakly so a view
    /// dismissed mid-sync doesn't keep itself alive for the rest of the run.
    private static func makeProgressForwarder(
        _ presenter: BackupConfigsPresenter?
    ) -> BackupSyncCoordinator.ProgressHandler {
        { [weak presenter] event in
            Task { @MainActor in
                presenter?.handle(event)
            }
        }
    }

    private func handle(_ event: BackupSyncCoordinator.ProgressEvent) {
        switch event {
        case .started(let id, _):
            syncingConfigIDs.insert(id)
        case .finished(let id, _, _):
            syncingConfigIDs.remove(id)
        }
        reload()
    }

    private func handleAddChoice(_ kind: SyncServiceKind) {
        switch kind {
        case .iCloud:
            interactor.addiCloud()
            withAnimation { reload() }
        case .webDAV:
            destination = .addWebDAV
        case .s3:
            destination = .addS3
        }
    }

    private func reload() {
        rows = interactor.allConfigs.map { config in
            BackupConfigRowItem(
                id: config.id,
                kind: config.kind,
                title: title(for: config),
                subtitle: subtitle(for: config),
                statusText: statusText(for: config),
                isSyncing: isSyncing(for: config),
                icon: icon(for: config.kind)
            )
        }
    }

    private func isSyncing(for config: BackupConfig) -> Bool {
        switch config.kind {
        case .iCloud:
            return interactor.cloudState.isSyncing
        case .webDAV, .s3:
            return syncingConfigIDs.contains(config.id)
        }
    }
}

private extension BackupConfigsPresenter {
    func title(for config: BackupConfig) -> String {
        switch config.kind {
        case .iCloud: String(localized: .backupConfigsRowIcloudTitle)
        case .webDAV: String(localized: .backupConfigsRowWebdavTitle)
        case .s3: String(localized: .backupConfigsRowS3Title)
        }
    }

    func subtitle(for config: BackupConfig) -> String? {
        switch config {
        case .iCloud:
            return nil
        case .webDAV(let entry):
            return entry.config.normalizedURL.host ?? entry.config.baseURL
        case .s3(let entry):
            return entry.config.bucket
        }
    }

    func statusText(for config: BackupConfig) -> String {
        switch config.kind {
        case .iCloud:
            return interactor.cloudState.shortDescription
        case .webDAV, .s3:
            if syncingConfigIDs.contains(config.id) {
                return String(localized: .syncSyncing)
            } else if let date = interactor.lastSyncDate(for: config.id) {
                return String(localized: .backupConfigsLastSynced(
                    date.formatted(date: .abbreviated, time: .shortened)
                ))
            } else {
                return String(localized: .backupConfigsNeverSynced)
            }
        }
    }

    func icon(for kind: SyncServiceKind) -> SettingsIcon {
        switch kind {
        case .iCloud: .iCloud
        case .webDAV: .webDAV
        case .s3: .s3
        }
    }
}

private extension CloudState {
    var shortDescription: String {
        switch self {
        case .unknown: String(localized: .syncChecking)
        case .disabled: String(localized: .syncDisabled)
        case .enabled(.synced): String(localized: .syncSynced)
        case .enabled(.syncing): String(localized: .syncSyncing)
        case .enabledNotAvailable: String(localized: .syncNotAvailable)
        }
    }
}
