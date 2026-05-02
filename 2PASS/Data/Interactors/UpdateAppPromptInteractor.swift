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
    private let cloudSyncInteractor: CloudSyncInteracting
    private let notificationCenter: NotificationCenter
    private let promptInterval: TimeInterval = 60 * 60 * 24

    private var progressTask: Task<Void, Never>?
    private var cloudStateTask: Task<Void, Never>?

    init(mainRepository: MainRepository, systemInteractor: SystemInteracting, cloudSyncInteractor: CloudSyncInteracting) {
        self.mainRepository = mainRepository
        self.systemInteractor = systemInteractor
        self.cloudSyncInteractor = cloudSyncInteractor
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
        // Two schema-not-supported sources, one cooldown gate: iCloud surfaces them via
        // `.cloudStateChanged` (its own state machine); file backends (WebDAV / S3) surface
        // them via `BackupSyncContainer.progressEvents()`. Both observers register here.
        //
        // Subscribing to the stream before `BackupSyncSetupInteractor.initialize()` runs is
        // safe — `progressEvents()` registers the continuation immediately; sessions only
        // yield once `setup(...)` has wired the providers later in app boot.
        let progressStream = mainRepository.backupSyncContainer.progressEvents()
        progressTask = Task.detached { [weak self] in
            for await event in progressStream {
                self?.handleBackupSyncProgressEvent(event)
            }
        }
        let cloudStateStream = notificationCenter.notifications(named: .cloudStateChanged)
        cloudStateTask = Task.detached { [weak self] in
            for await _ in cloudStateStream {
                self?.handleCloudStateChange()
            }
        }
        Log("UpdateAppPromptInteractor - Started monitoring iCloud and backup-sync state changes", module: .interactor)
    }

    func stopMonitoring() {
        progressTask?.cancel()
        cloudStateTask?.cancel()
        Log("UpdateAppPromptInteractor - Stopped monitoring iCloud and backup-sync state changes", module: .interactor)
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

    func handleCloudStateChange() {
        let cloudState = cloudSyncInteractor.currentState

        if shouldShowPrompt() {
            switch cloudState {
            case .enabledNotAvailable(reason: .schemaNotSupported(let schemaVersion)):
                Log("UpdateAppPromptInteractor - iCloud schema not supported detected (v\(schemaVersion)), showing update prompt", module: .interactor)

                Task { @MainActor in
                    self.postUpdatePromptNotification(.iCloudSchemeNotSupported(schemaVersion: schemaVersion))
                }
            default:
                break
            }
        }
    }

    func handleBackupSyncProgressEvent(_ event: BackupSyncSession.ProgressEvent) {
        guard case .finished(_, _, .failure(.schemaNotSupported(let version))) = event else {
            return
        }
        guard shouldShowPrompt() else { return }
        Log("UpdateAppPromptInteractor - File backend schema not supported (v\(version)), showing update prompt", module: .interactor)
        Task { @MainActor in
            self.postUpdatePromptNotification(.webDAVSchemeNotSupported(schemaVersion: version))
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
