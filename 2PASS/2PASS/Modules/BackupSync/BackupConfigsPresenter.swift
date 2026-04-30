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

    var isEmpty: Bool { rows.isEmpty }
    var canAddiCloud: Bool { !rows.contains { $0.kind == .iCloud } }

    private let interactor: BackupConfigsModuleInteracting

    init(interactor: BackupConfigsModuleInteracting) {
        self.interactor = interactor
        reload()
        interactor.cloudStateChanged = { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        interactor.backupSyncActivityChanged = { [weak self] in
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
        interactor.syncAll(onEvent: nil)
    }

    func onCancelSyncAll() {
        interactor.cancelCurrentSync()
    }

    func onSyncRow(_ row: BackupConfigRowItem) {
        guard !isSyncing else { return }
        Task { [weak self] in
            await self?.interactor.sync(id: row.id, onEvent: nil)
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
        isSyncing = interactor.currentActivity.isRunning
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
        let activeConfigIDs = interactor.currentActivity.activeConfigIDs
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
        let activeConfigIDs = interactor.currentActivity.activeConfigIDs
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
