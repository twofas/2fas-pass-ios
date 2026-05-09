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
    case editWebDAV(configID: UUID)
    case editS3(configID: UUID)
    case removeConfirmation(name: String, onConfirm: Callback)

    var id: String {
        switch self {
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
    /// Localized "Last error: … (date)" string for the most recent in-process failure on this
    /// config, or `nil` if the last attempt succeeded / no attempt has run / a sync is currently
    /// in flight (active syncs suppress the stale error to avoid mixing past and present state).
    let errorText: String?
    let isSyncing: Bool
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
    var errorCount: Int { rows.filter { $0.errorText != nil }.count }

    private let interactor: BackupConfigsModuleInteracting
    /// Local mirror of which configs are currently mid-service. Seeded once at init from
    /// `interactor.currentActivity.activeConfigIDs` (covers "presenter opened mid-sync"),
    /// then maintained by consuming `syncEvents()`. Drives per-row spinner state via
    /// `isSyncing(for:)`.
    private var activeConfigIDs: Set<UUID> = []
    /// `@ObservationIgnored` — the task handle isn't observable UI state, so `@Observable`
    /// shouldn't synthesize tracking storage for it (the synth storage trips the
    /// "`nonisolated` cannot be applied to mutable stored properties" rule).
    /// `nonisolated(unsafe)` because `deinit` is implicitly nonisolated on `@MainActor`
    /// classes; the handle is written once at the end of `init`, read only by `deinit` to
    /// cancel — no concurrent mutation, so the `unsafe` opt-out is sound.
    @ObservationIgnored
    private var syncEventTask: Task<Void, Never>?
    /// RAII observer for `BackupConfigsDidChange` posted by `BackupSyncContainer.saveConfigs(_:)`
    /// after every successful persistence (add / update / remove). Drives `reload()` so newly
    /// added/removed config rows animate in even when triggered from another screen (e.g.
    /// iCloud toggled via QuickSetup while BackupConfigs is off-stack). The token auto-removes
    /// the underlying NotificationCenter observer on `cancel()` or `deinit`, whichever fires first.
    @ObservationIgnored
    private var configsChangeToken: Notifications.ObservationToken?
    /// Skips snapshot on first onAppear (init seeded); re-appearances catch up after off-screen.

    init(interactor: BackupConfigsModuleInteracting) {
        self.interactor = interactor
        // Seed rows for first body pass; without this, onAppear's later reload causes an empty-state flash.
        snapshotActivity()
    }

    isolated deinit {
        // Safety net: `onDisappear` should cancel first under normal lifecycle, but if the
        // presenter is torn down without the view ever firing onDisappear (rare but possible),
        // the AsyncStream continuation would otherwise leak. The `configsChangeToken`'s own
        // `deinit` would clean up its observer too — explicit cancel here for symmetry with
        // the sync-event task.
        syncEventTask?.cancel()
        configsChangeToken?.cancel()
    }

    private func snapshotActivity() {
        let snapshot = interactor.currentActivity
        activeConfigIDs = snapshot.activeConfigIDs
        isSyncing = snapshot.isRunning
        reload()
    }

    private func subscribeToSyncEvents() {
        syncEventTask?.cancel()
        syncEventTask = Task { [weak self, interactor] in
            for await event in interactor.syncEvents() {
                self?.handle(event)
            }
        }
    }

    private func subscribeToConfigsChanges() {
        configsChangeToken?.cancel()
        configsChangeToken = NotificationCenter.default.addObserver(
            of: BackupConfigsDidChange.self
        ) { [weak self] _ in
            // Posters call `NotificationCenter.default.post(...)` from whichever thread the
            // mutating method ran on; hop to MainActor for the UI rebuild. `withAnimation`
            // matches the `addiCloud` / `onDelete` paths' local-mutation animation.
            Task { @MainActor in
                guard let self else { return }
                withAnimation { self.reload() }
            }
        }
    }

    private func handle(_ event: BackupSyncSession.Event) {
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
        subscribeToSyncEvents()
        subscribeToConfigsChanges()
    }

    func onDisappear() {
        syncEventTask?.cancel()
        syncEventTask = nil
        configsChangeToken?.cancel()
        configsChangeToken = nil
    }

    func addiCloud() {
        interactor.addiCloud()
        withAnimation { reload() }
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
            self.interactor.remove(id: row.id)
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

    private func reload() {
        rows = interactor.allConfigs.map { config in
            BackupConfigRowItem(
                id: config.id,
                kind: config.kind,
                title: title(for: config),
                subtitle: subtitle(for: config),
                statusText: statusText(for: config),
                errorText: errorText(for: config),
                isSyncing: isSyncing(for: config)
            )
        }
    }

    private func isSyncing(for config: BackupConfig) -> Bool {
        activeConfigIDs.contains(config.id)
    }
}

private extension BackupConfigsPresenter {
    func title(for config: BackupConfig) -> String {
        switch config {
        case .iCloud:
            return String(localized: .backupConfigsRowIcloudTitle)
        case .webDAV(let entry):
            let host = entry.config.normalizedURL.host ?? entry.config.baseURL
            let domain = interactor.displayDomain(from: host)
            return domain.isEmpty ? String(localized: .backupConfigsRowWebdavTitle) : domain
        case .s3(let entry):
            let domain = interactor.displayDomain(from: entry.config.endpoint.host() ?? "")
            return domain.isEmpty ? String(localized: .backupConfigsRowS3Title) : domain
        }
    }

    func subtitle(for config: BackupConfig) -> String? {
        switch config {
        case .iCloud:
            return nil
        case .webDAV(let entry):
            let trimmed = String(entry.config.normalizedURL.path.trimmingPrefix("/"))
            return trimmed.isEmpty ? nil : trimmed
        case .s3(let entry):
            return entry.config.bucket
        }
    }

    func statusText(for config: BackupConfig) -> String {
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

    /// "Last error: <localized error message>" for the most recent recorded failure, or `nil`.
    /// Suppressed while a sync is currently in flight for this config — showing a stale error
    /// next to a live progress spinner would mix past and present state; the in-flight attempt
    /// is the one that matters now, and it'll either replace or clear the record on finish.
    ///
    /// The localized text comes from `BackupSyncError.errorDescription` (LocalizedError
    /// conformance) which resolves through the Backup module's own `Localizable.xcstrings`.
    /// Render-time localization, not write-time — a system-language switch re-localizes the
    /// cached error on the next presenter reload.
    func errorText(for config: BackupConfig) -> String? {
        if isSyncing(for: config) { return nil }
        guard let error = interactor.lastSyncError(for: config.id),
              let message = error.errorDescription
        else { return nil }
        return String(localized: .backupConfigsLastError(message))
    }
}


