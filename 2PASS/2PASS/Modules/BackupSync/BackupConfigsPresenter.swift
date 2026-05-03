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
    /// Call-level "is a sync in flight overall?" — driven by `.sessionStarted` /
    /// `.sessionFinished` from the container, which span the orchestration window
    /// (services-list construction, inter-service gaps, post-results notification). Distinct
    /// from `activeConfigIDs.isEmpty`, which only reflects per-service activity and goes
    /// briefly empty between services even while the call hasn't returned.
    private(set) var isSyncing: Bool = false

    var isEmpty: Bool { rows.isEmpty }
    var canAddiCloud: Bool { !rows.contains { $0.kind == .iCloud } }

    private let interactor: BackupConfigsModuleInteracting
    /// Local mirror of which configs are currently mid-service. Seeded once at init from
    /// `interactor.currentActivity.activeConfigIDs` (covers "presenter opened mid-sync"),
    /// then maintained by consuming `progressEvents()`. Drives per-row spinner state via
    /// `isSyncing(for:)`.
    private var activeConfigIDs: Set<UUID> = []
    /// `@ObservationIgnored` — the task handle isn't observable UI state, so `@Observable`
    /// shouldn't synthesize tracking storage for it (the synth storage trips the
    /// "`nonisolated` cannot be applied to mutable stored properties" rule).
    /// `nonisolated(unsafe)` because `deinit` is implicitly nonisolated on `@MainActor`
    /// classes; the handle is written once at the end of `init`, read only by `deinit` to
    /// cancel — no concurrent mutation, so the `unsafe` opt-out is sound.
    @ObservationIgnored
    nonisolated(unsafe) private var progressTask: Task<Void, Never>?

    init(interactor: BackupConfigsModuleInteracting) {
        self.interactor = interactor
        interactor.cloudStateChanged = { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        // Both initial state seeding (`snapshotActivity`) and the `progressEvents`
        // subscription happen in `onAppear` — keeps all data work tied to view visibility
        // and avoids processing events for a hidden screen. See `onDisappear` for teardown.
    }

    deinit {
        // Safety net: `onDisappear` should cancel first under normal lifecycle, but if the
        // presenter is torn down without the view ever firing onDisappear (rare but possible),
        // the AsyncStream continuation would otherwise leak.
        progressTask?.cancel()
    }

    private func snapshotActivity() {
        let snapshot = interactor.currentActivity
        activeConfigIDs = snapshot.activeConfigIDs
        isSyncing = snapshot.isRunning
        reload()
    }

    private func subscribeToProgress() {
        progressTask?.cancel()
        progressTask = Task { [weak self, interactor] in
            for await event in interactor.progressEvents() {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: BackupSyncSession.ProgressEvent) {
        switch event {
        case .sessionStarted:
            isSyncing = true
        case .sessionFinished:
            isSyncing = false
        case .started(let id, _):
            activeConfigIDs.insert(id)
        case .finished(let id, _, _):
            activeConfigIDs.remove(id)
        }
        reload()
    }

    func onAppear() {
        snapshotActivity()
        subscribeToProgress()
    }

    func onDisappear() {
        progressTask?.cancel()
        progressTask = nil
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

    func onSyncAllNow() {
        // User-initiated tap — wrap in `Task` (not `Task.detached`) so the work inherits
        // MainActor's `.userInitiated` priority. Background post-mutation syncs use the
        // sync-overload fire-and-forget path; this one wants the user-facing priority.
        Task { [interactor] in
            await interactor.syncAll()
        }
    }

    func onCancelSync() {
        interactor.cancelCurrentSync()
    }

    func onSyncRow(_ row: BackupConfigRowItem) {
        Task { [interactor] in
            await interactor.sync(id: row.id)
        }
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
            return interactor.cloudState.isSyncing || activeConfigIDs.contains(config.id)
        case .webDAV, .s3:
            return activeConfigIDs.contains(config.id)
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
            if activeConfigIDs.contains(config.id) {
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
