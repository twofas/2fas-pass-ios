// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

public enum UpdateAppPromptRequestReason {
    case webDAVSchemeNotSupported(schemaVersion: Int)
    case iCloudSchemeNotSupported(schemaVersion: Int)
}

public enum UpdateAppPromptState {
    case hidden
    case unsupportedAppVersion(minimalVersion: String)
}

public protocol UpdateAppPromptInteracting: AnyObject {

    var appVersionPromptState: UpdateAppPromptState { get }

    func markPromptAsShown()
}

final class UpdateAppPromptInteractor: UpdateAppPromptInteracting {

    private let mainRepository: MainRepository
    private let systemInteractor: SystemInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let notificationCenter: NotificationCenter
    private let promptInterval: TimeInterval = 60 * 60 * 24

    private var syncEventTask: Task<Void, Never>?

    init(
        mainRepository: MainRepository,
        systemInteractor: SystemInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting
    ) {
        self.mainRepository = mainRepository
        self.systemInteractor = systemInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
        self.notificationCenter = NotificationCenter.default

        startMonitoring()
    }

    var appVersionPromptState: UpdateAppPromptState {
        guard let minimalVersion = mainRepository.minimalAppVersionSupported else {
            return .hidden
        }
        let currentVersion = systemInteractor.appVersion
        if isVersion(currentVersion, olderThan: minimalVersion) && shouldShowPrompt() {
            return .unsupportedAppVersion(minimalVersion: minimalVersion)
        } else {
            return .hidden
        }
    }

    func markPromptAsShown() {
        mainRepository.setLastAppUpdatePromptDate(Date())
    }

    deinit {
        stopMonitoring()
    }
}

private extension UpdateAppPromptInteractor {

    func startMonitoring() {
        // After the CloudSync refactor, iCloud schema-not-supported errors flow through the
        // unified `syncEvents()` stream alongside WebDAV / S3 — `CloudSyncAdapter.performSync`
        // surfaces them as `BackupSyncError.schemaNotSupported(version)` on `.finished` just
        // like the file-based adapters. The pre-refactor `.cloudStateChanged` observer path
        // (which polled `cloudSync.currentState` for the granular reason) is gone; the only
        // signal is now "we attempted a sync and got back a schema-not-supported error."
        //
        // Subscribing to the stream before `BackupSyncSetupInteractor.initialize()` runs is
        // safe — `syncEvents()` registers the continuation immediately; sessions only yield
        // once `setup(...)` has wired the providers later in app boot.
        let syncEventStream = syncTriggerInteractor.syncEvents()
        syncEventTask = Task.detached { [weak self] in
            for await event in syncEventStream {
                self?.handleBackupSyncEvent(event)
            }
        }
        Log("UpdateAppPromptInteractor - Started monitoring backup-sync schema state", module: .interactor)
    }

    func stopMonitoring() {
        syncEventTask?.cancel()
        Log("UpdateAppPromptInteractor - Stopped monitoring backup-sync schema state", module: .interactor)
    }

    func shouldShowPrompt() -> Bool {
        guard let lastPromptDate = mainRepository.lastAppUpdatePromptDate else {
            return true
        }

        let timeSinceLastPrompt = Date().timeIntervalSince(lastPromptDate)
        return timeSinceLastPrompt >= promptInterval
    }

    func isVersion(_ version1: String, olderThan version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Components.count, v2Components.count)
        for i in 0..<maxLength {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0

            if v1Value < v2Value {
                return true
            } else if v1Value > v2Value {
                return false
            }
        }

        return false
    }

    func handleBackupSyncEvent(_ event: BackupSyncSession.Event) {
        guard case .finished(_, let kind, .failure(.schemaNotSupported(let version))) = event else {
            return
        }
        guard shouldShowPrompt() else { return }
        let reason: UpdateAppPromptRequestReason = (kind == .iCloud)
            ? .iCloudSchemeNotSupported(schemaVersion: version)
            : .webDAVSchemeNotSupported(schemaVersion: version)
        Log("UpdateAppPromptInteractor - \(String(describing: kind)) schema not supported (v\(version)), showing update prompt", module: .interactor)
        Task { @MainActor in
            self.postUpdatePromptNotification(reason)
        }
    }

    func postUpdatePromptNotification(_ state: UpdateAppPromptRequestReason) {
        notificationCenter.post(
            name: .showUpdateAppPrompt,
            object: nil,
            userInfo: [Notification.showUpdateAppPromptReasonKey: state]
        )
    }
}
