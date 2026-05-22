// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import SwiftUI
import Backup
import Common
import CommonUI

enum BackupConfigsDestination: RouterDestination {
    /// `onClose` receives the saved config's id (or `nil` on cancel) and clears
    /// `destination`. `savedConfigID` is a reactive resolver so the matched-zoom
    /// destination re-targets the new row before the sheet animates away.
    case add(
        onClose: @MainActor (BackupConfig.ID?) -> Void,
        savedConfigID: @MainActor () -> BackupConfig.ID?
    )
    case editWebDAV(configID: BackupConfig.ID, onClose: @MainActor (BackupConfig.ID?) -> Void)
    case editS3(configID: BackupConfig.ID, onClose: @MainActor (BackupConfig.ID?) -> Void)
    case removeConfirmation(name: String, onConfirm: @MainActor () -> Void)

    var id: String {
        switch self {
        case .add: "add"
        case .editWebDAV(let configID, _): "editWebDAV-\(configID)"
        case .editS3(let configID, _): "editS3-\(configID)"
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
    /// Set by the picker's `onClose` on save; drives the add sheet's matched-zoom
    /// destination to point at the new row instead of the `+` button. Cleared before
    /// each new open.
    private(set) var savedConfigIDFromPicker: BackupConfig.ID?
    private(set) var configs: [BackupConfigCellItem] = []
    /// Call-level "any sync in flight?" — spans inter-service gaps, unlike
    /// `activeConfigIDs.isEmpty` which only reflects per-service activity.
    private(set) var isSyncing: Bool = false

    var isEmpty: Bool { configs.isEmpty }
    var errorCount: Int { configs.filter { $0.errorText != nil }.count }

    private let interactor: BackupConfigsModuleInteracting
    /// Local mirror of mid-service config ids. Seeded from `currentActivity` and maintained
    /// via `syncEvents()`; drives per-row spinner state and the "suppress stale error while
    /// syncing" rule.
    private var activeConfigIDs: Set<BackupConfig.ID> = []
    @ObservationIgnored
    private var syncEventTask: Task<Void, Never>?
    @ObservationIgnored
    private var configsChangeTask: Task<Void, Never>?

    init(interactor: BackupConfigsModuleInteracting) {
        self.interactor = interactor
        // Seed rows for first body pass; without this, onAppear's later reload flashes empty.
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
        // Reset so a cancel/iCloud dismiss zooms back to the `+` button.
        savedConfigIDFromPicker = nil
        destination = .add(
            onClose: { [weak self] configID in
                guard let self else { return }
                if let configID {
                    // Set BEFORE clearing `destination` so SwiftUI re-evaluates the
                    // reactive matched-zoom modifier with the new row's source id
                    // before the sheet animates away. `Task` defers the clear one
                    // run-loop hop so observation propagates first.
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
        // Edit's matched-zoom id is stable, so a synchronous `destination = nil` is fine
        // (unlike the add flow, which has to defer for observation to propagate first).
        let onClose: @MainActor (BackupConfig.ID?) -> Void = { [weak self] _ in
            self?.destination = nil
        }
        switch row.kind {
        case .webDAV:
            destination = .editWebDAV(configID: row.id, onClose: onClose)
        case .s3:
            destination = .editS3(configID: row.id, onClose: onClose)
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
        // `Task` (not `Task.detached`) so the work inherits MainActor's `.userInitiated`
        // priority — background sync uses the fire-and-forget overload instead.
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
        // Safety net for presenters torn down without an onDisappear fire.
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
        // Newest first so a freshly-added row is on-screen — matched-zoom-back can only
        // target a mounted source view.
        configs = interactor.allConfigs.reversed().map(makeCellItem(for:))
    }

    func makeCellItem(for config: BackupConfig) -> BackupConfigCellItem {
        let isSyncing = activeConfigIDs.contains(config.id)

        let title: String
        let subtitle: String?
        switch config {
        case .iCloud:
            title = String(localized: .backupConfigsProviderIcloudTitle)
            subtitle = nil
        case .webDAV(let entry):
            let host = entry.config.normalizedURL.host ?? entry.config.baseURL
            let domain = interactor.displayDomain(from: host)
            title = domain.isEmpty ? String(localized: .backupConfigsProviderWebdavTitle) : domain
            let trimmed = String(entry.config.normalizedURL.path.trimmingPrefix("/"))
            subtitle = trimmed.isEmpty ? nil : trimmed
        case .s3(let entry):
            let domain = interactor.displayDomain(from: entry.config.endpoint.host() ?? "")
            title = domain.isEmpty ? String(localized: .backupConfigsProviderS3Title) : domain
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

        // Hide stale error while a sync is in flight — the live attempt will replace or
        // clear it on finish.
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
