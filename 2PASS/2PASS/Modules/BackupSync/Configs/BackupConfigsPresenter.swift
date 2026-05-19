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

enum BackupConfigsDestination: RouterDestination {
    /// `onClose` receives the new config's id on a successful save (so the presenter
    /// can flip `savedConfigIDFromPicker` and the parent's matched-zoom destination
    /// re-targets the new row before the sheet animates away), or `nil` on plain
    /// cancel/dismiss. The closure is also responsible for clearing `destination`
    /// — the picker view doesn't know it's hosted in a sheet.
    ///
    /// `savedConfigID` is a reactive resolver — read inside `MatchedZoomDestinationModifier`'s
    /// body via `matchedZoomDestination(id: savedConfigID()..., in:)`'s autoclosure,
    /// so observation on `savedConfigIDFromPicker` re-fires the zoom-target update
    /// mid-dismiss. Carrying the resolver here keeps the Router stateless: no
    /// presenter ref.
    case add(
        onClose: (BackupConfig.ID?) -> Void,
        savedConfigID: @MainActor () -> BackupConfig.ID?
    )
    case editWebDAV(configID: BackupConfig.ID)
    case editS3(configID: BackupConfig.ID)
    case removeConfirmation(name: String, onConfirm: Callback)

    var id: String {
        switch self {
        case .add: "add"
        case .editWebDAV(let configID): "editWebDAV-\(configID)"
        case .editS3(let configID): "editS3-\(configID)"
        case .removeConfirmation(let name, _): "removeConfirmation-\(name)"
        }
    }
}

struct BackupConfigCellItem: Identifiable, Equatable {
    let id: BackupConfig.ID
    let kind: BackupConfig.Service
    let title: String
    let subtitle: String?
    let statusText: String
    let errorText: String?
    let isSyncing: Bool
}

@Observable @MainActor
final class BackupConfigsPresenter {

    var destination: BackupConfigsDestination?
    /// Set by the picker's `onClose` when its inner form saves successfully — the new
    /// config's UUID. Drives the add sheet's matched-zoom destination to point at the
    /// freshly-added row instead of the `+` button, so the dismiss animates the sheet
    /// down INTO the new row. Cleared by `onAddPressed()` before each new open so
    /// cancel/iCloud paths zoom back to the `+` button.
    private(set) var savedConfigIDFromPicker: BackupConfig.ID?
    private(set) var configs: [BackupConfigCellItem] = []
    /// Call-level "is a sync in flight overall?" — driven by `.sessionStarted` /
    /// `.sessionFinished` from the container, which span the orchestration window
    /// (services-list construction, inter-service gaps, post-results notification). Distinct
    /// from `activeConfigIDs.isEmpty`, which only reflects per-service activity and goes
    /// briefly empty between services even while the call hasn't returned.
    private(set) var isSyncing: Bool = false

    var isEmpty: Bool { configs.isEmpty }
    var errorCount: Int { configs.filter { $0.errorText != nil }.count }

    private let interactor: BackupConfigsModuleInteracting
    /// Local mirror of which configs are currently mid-service. Seeded once at init from
    /// `interactor.currentActivity.activeConfigIDs` (covers "presenter opened mid-sync"),
    /// then maintained by consuming `syncEvents()`. Drives per-row spinner state and the
    /// "suppress stale error while syncing" rule via `makeCellItem(for:)`.
    private var activeConfigIDs: Set<BackupConfig.ID> = []
    /// `@ObservationIgnored` — the task handle isn't observable UI state, so `@Observable`
    /// shouldn't synthesize tracking storage for it (the synth storage trips the
    /// "`nonisolated` cannot be applied to mutable stored properties" rule).
    /// `nonisolated(unsafe)` because `deinit` is implicitly nonisolated on `@MainActor`
    /// classes; the handle is written once at the end of `init`, read only by `deinit` to
    /// cancel — no concurrent mutation, so the `unsafe` opt-out is sound.
    @ObservationIgnored
    private var syncEventTask: Task<Void, Never>?
    /// Long-lived `for await` consumer of `interactor.configsDidChange` — fires once per
    /// successful add / update / remove from `BackupSyncContainer.saveConfigs(_:)`. Drives
    /// `reload()` so newly added/removed config rows animate in even when triggered from
    /// another screen (e.g. iCloud toggled via QuickSetup while BackupConfigs is off-stack).
    /// Cancelled in `onDisappear`, with `deinit` as a safety net — same lifecycle as
    /// `syncEventTask` above.
    @ObservationIgnored
    private var configsChangeTask: Task<Void, Never>?
    /// Skips snapshot on first onAppear (init seeded); re-appearances catch up after off-screen.

    init(interactor: BackupConfigsModuleInteracting) {
        self.interactor = interactor
        // Seed rows for first body pass; without this, onAppear's later reload causes an empty-state flash.
        snapshotActivity()
    }
    
    func onAppear() {
        snapshotActivity()
        subscribeToSyncEvents()
        subscribeToConfigsChanges()
    }

    func onDisappear() {
        syncEventTask?.cancel()
        syncEventTask = nil
        configsChangeTask?.cancel()
        configsChangeTask = nil
    }

    func onAddPressed() {
        // Clear before showing so each fresh picker open zooms from the `+` button.
        // The picker's `onClose` writes back into `savedConfigIDFromPicker` only on
        // a successful save, at which point the matched-zoom destination flips to
        // the new row.
        savedConfigIDFromPicker = nil
        destination = .add(
            onClose: { [weak self] configID in
                guard let self else { return }
                if let configID {
                    // Set BEFORE clearing `destination` so SwiftUI re-evaluates the
                    // reactive matched-zoom modifier with the new row's source ID
                    // before the sheet starts animating away. `Task` defers the
                    // destination clear one run-loop hop so observation propagates
                    // first.
                    self.savedConfigIDFromPicker = configID
                }
                Task { @MainActor [weak self] in
                    self?.destination = nil
                }
            },
            savedConfigID: { [weak self] in self?.savedConfigIDFromPicker }
        )
    }

    func onSelect(_ row: BackupConfigCellItem) {
        switch row.kind {
        case .webDAV:
            destination = .editWebDAV(configID: row.id)
        case .s3:
            destination = .editS3(configID: row.id)
        case .iCloud:
            break
        }
    }

    func onDelete(_ row: BackupConfigCellItem) {
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

    func onSyncRow(_ row: BackupConfigCellItem) {
        Task { [interactor] in
            await interactor.sync(id: row.id)
        }
    }
    
    func onCancelSync() {
        interactor.cancelCurrentSync()
    }

    isolated deinit {
        // Safety net: `onDisappear` should cancel first under normal lifecycle, but if the
        // presenter is torn down without the view ever firing onDisappear (rare but possible),
        // the AsyncStream continuations would otherwise leak.
        syncEventTask?.cancel()
        configsChangeTask?.cancel()
    }
}

private extension BackupConfigsPresenter {
    
    func snapshotActivity() {
        let snapshot = interactor.currentActivity
        activeConfigIDs = snapshot.activeConfigIDs
        isSyncing = snapshot.isRunning
        reload()
    }

    func subscribeToSyncEvents() {
        syncEventTask?.cancel()
        syncEventTask = Task { [weak self, interactor] in
            for await event in interactor.syncEvents() {
                self?.handle(event)
            }
        }
    }

    func subscribeToConfigsChanges() {
        configsChangeTask?.cancel()
        configsChangeTask = Task { [weak self, interactor] in
            for await _ in interactor.configsDidChange {
                guard let self else { return }
                // Animate so row additions/removals slide in regardless of whether the
                // change came from this screen or another (e.g. iCloud toggled via
                // QuickSetup while off-stack, or added via the picker sheet).
                withAnimation { self.reload() }
            }
        }
    }

    func handle(_ event: BackupSyncSession.Event) {
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

    func reload() {
        // Newest config first so a freshly-added row appears at the top of the visible list
        // — required for the picker's matched-zoom-back animation, which can only target a
        // source view that's actually mounted on-screen. Off-screen rows (below the fold)
        // wouldn't have a registered `.matchedZoomSource(...)` for iOS to find.
        configs = interactor.allConfigs.reversed().map(makeCellItem(for:))
    }
    
    /// Builds a single row's view model from a config. Computes `isSyncing` once at the top
    /// so every derived field — including the "suppress stale error while a sync is in flight"
    /// rule — sees the same activity snapshot, instead of each field re-reading `activeConfigIDs`
    /// and risking a desync if a future field forgets the suppression invariant.
    func makeCellItem(for config: BackupConfig) -> BackupConfigCellItem {
        let isSyncing = activeConfigIDs.contains(config.id)

        let title: String
        let subtitle: String?
        switch config {
        case .iCloud:
            title = String(localized: .backupConfigsRowIcloudTitle)
            subtitle = nil
        case .webDAV(let entry):
            let host = entry.config.normalizedURL.host ?? entry.config.baseURL
            let domain = interactor.displayDomain(from: host)
            title = domain.isEmpty ? String(localized: .backupConfigsRowWebdavTitle) : domain
            let trimmed = String(entry.config.normalizedURL.path.trimmingPrefix("/"))
            subtitle = trimmed.isEmpty ? nil : trimmed
        case .s3(let entry):
            let domain = interactor.displayDomain(from: entry.config.endpoint.host() ?? "")
            title = domain.isEmpty ? String(localized: .backupConfigsRowS3Title) : domain
            subtitle = entry.config.bucket
        }

        let statusText: String
        if isSyncing {
            statusText = String(localized: .syncSyncing)
        } else if let date = interactor.lastSyncDate(for: config.id) {
            statusText = String(localized: .backupConfigsLastSynced(
                date.formatted(date: .abbreviated, time: .shortened)
            ))
        } else {
            statusText = String(localized: .backupConfigsNeverSynced)
        }

        // Suppress stale error while a sync is in flight: showing a past failure next to a live
        // progress spinner would mix present and past state. The in-flight attempt is what
        // matters now and it'll either replace or clear the record on finish. Error message
        // resolves through `BackupSyncError.errorDescription` (LocalizedError conformance from
        // the Backup module's own xcstrings) — render-time localization, not write-time, so a
        // system-language switch re-localizes on the next reload.
        let errorText = isSyncing ? nil : interactor.lastSyncError(for: config.id)?.errorDescription

        return BackupConfigCellItem(
            id: config.id,
            kind: config.service,
            title: title,
            subtitle: subtitle,
            statusText: statusText,
            errorText: errorText,
            isSyncing: isSyncing
        )
    }
}
