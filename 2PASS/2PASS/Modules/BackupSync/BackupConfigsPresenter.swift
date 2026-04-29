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

    /// IDs of configs whose sync is currently in flight (per-row "Sync now" or covered by the
    /// global "Sync now"). webDAV/s3 rows derive their `isSyncing` from this set; iCloud rows
    /// derive theirs from `interactor.cloudState.isSyncing` since CloudKit owns its own state.
    private var syncingConfigIDs: Set<UUID> = []

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

    /// Re-runs `reload()` so each row's `statusText` recomputes against the current `Date`.
    /// Called from a periodic `.task` in the View — without it, "Synced 5m ago" would stay
    /// "Synced 5m ago" indefinitely while the user looks at the screen.
    func refresh() {
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
        // Mark every webDAV/s3 row as in-flight for the duration of the global run. iCloud is
        // skipped: it has its own observable state machine via `CloudState`.
        let inFlightIDs = rows.filter { $0.kind != .iCloud }.map(\.id)
        syncingConfigIDs.formUnion(inFlightIDs)
        reload()
        Task { [weak self] in
            await self?.interactor.syncAll()
            await MainActor.run {
                self?.isSyncing = false
                self?.syncingConfigIDs.subtract(inFlightIDs)
                self?.reload()
            }
        }
    }

    func onSyncRow(_ row: BackupConfigRowItem) {
        guard !syncingConfigIDs.contains(row.id) else { return }
        syncingConfigIDs.insert(row.id)
        reload()
        Task { [weak self] in
            await self?.interactor.sync(id: row.id)
            await MainActor.run {
                self?.syncingConfigIDs.remove(row.id)
                self?.reload()
            }
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
                // `Date.RelativeFormatStyle(presentation: .named, unitsStyle: .narrow)` produces
                // a localized "now" for sub-minute timestamps, then "1m ago", "1h ago",
                // "yesterday", etc. Replaces the legacy `RelativeDateTimeFormatter` which
                // returned ugly "0 sec ago" / "in 0 sec" strings for fresh syncs.
                return String(localized: .backupConfigsLastSynced(date.formatted(Self.relativeStyle)))
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

    static let relativeStyle: Date.RelativeFormatStyle = .init(
        presentation: .named,
        unitsStyle: .narrow
    )
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
