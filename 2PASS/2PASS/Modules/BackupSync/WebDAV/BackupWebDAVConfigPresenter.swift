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

enum BackupWebDAVConfigDestination: RouterDestination {
    case errorAlert(message: String)

    var id: String {
        switch self {
        case .errorAlert: "errorAlert"
        }
    }
}

@Observable @MainActor
final class BackupWebDAVConfigPresenter {

    var url: String = ""
    var allowTLSOff = false
    var username: String = ""
    var password: String = ""

    /// `true` while the probe is in flight. Drives the button's spinner and disabled state.
    private(set) var isTesting: Bool = false
    /// Bumped once each time the probe + save succeeds; the view observes this to fire a
    /// success haptic. Counter (not Bool) so two consecutive successes still register as
    /// distinct value changes and re-fire `.sensoryFeedback`.
    private(set) var successFeedbackTrigger: Int = 0
    /// Bumped once each time the probe fails (other than user cancellation); drives the
    /// error haptic. Same counter rationale as `successFeedbackTrigger`.
    private(set) var failureFeedbackTrigger: Int = 0
    /// Drives the toolbar Save/Done button's enabled state. URL must parse to a normalized
    /// secure URL before tapping is allowed; in edit mode the button additionally requires
    /// at least one field to differ from the loaded values — re-saving an unchanged config
    /// would just trigger a redundant probe.
    var canSave: Bool {
        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard let normalized = interactor.normalizeURL(url) else {
            return false
        }
        guard interactor.isSecureURL(normalized) else {
            return false
        }
        if isEditMode, !hasUnsavedChanges {
            return false
        }
        return true
    }
    var destination: BackupWebDAVConfigDestination?

    let isEditMode: Bool

    private let interactor: BackupWebDAVConfigModuleInteracting
    private let configID: BackupConfig.ID?
    /// Called on save (with the saved config's id) or programmatic close (with `nil`).
    /// Toolbar Cancel goes through `\.dismiss` directly and bypasses this callback.
    private let onClose: (BackupConfig.ID?) -> Void
    /// Held so the in-flight probe can be torn down on dismissal — without this the network
    /// request continues until the server responds even after the user taps Cancel.
    @ObservationIgnored
    private var testTask: Task<Void, Never>?
    /// Snapshot of the config as it was when the form opened. Drives the per-field "changed"
    /// indicators that highlight modified rows in edit mode. Stays nil in add mode.
    @ObservationIgnored
    private var originalSnapshot: BackupWebDAVConfig?

    init(interactor: BackupWebDAVConfigModuleInteracting, configID: BackupConfig.ID?, onClose: @escaping (BackupConfig.ID?) -> Void) {
        self.interactor = interactor
        self.configID = configID
        self.onClose = onClose
        self.isEditMode = configID != nil
    }

    func onAppear() {
        guard let existing = interactor.existingConfig else { return }
        originalSnapshot = existing
        url = existing.baseURL
        allowTLSOff = existing.allowTLSOff
        username = existing.login ?? ""
        password = existing.password ?? ""
    }

    var urlChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return url != original.baseURL
    }
    var allowTLSOffChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return allowTLSOff != original.allowTLSOff
    }
    var usernameChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return username != (original.login ?? "")
    }
    var passwordChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return password != (original.password ?? "")
    }
    var hasUnsavedChanges: Bool {
        if isEditMode {
            return urlChanged
                || allowTLSOffChanged
                || usernameChanged
                || passwordChanged
        }
        return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || allowTLSOff
            || !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !password.isEmpty
    }

    /// Programmatic close without saving. Routes through `onClose` so the close request
    /// reaches whoever owns the form's host presentation — required in add mode (where
    /// the form is pushed inside the picker's `NavigationStack`, so a form-local
    /// `@Environment(\.dismiss)` would only pop back to the picker), and consistent with
    /// edit mode (where `onClose` is wired to a closure that dismisses the sheet).
    func close() {
        onClose(nil)
    }

    func onSave() {
        guard !isTesting else { return }

        guard let normalizedURL = interactor.normalizeURL(url) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorWrongDirectoryUrl))
            return
        }
        guard interactor.isSecureURL(normalizedURL) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorIncorrectUrl))
            return
        }

        let config = BackupWebDAVConfig(
            baseURL: url,
            normalizedURL: normalizedURL,
            allowTLSOff: allowTLSOff,
            login: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password
        )

        isTesting = true

        testTask = Task { [weak self] in
            do {
                try await self?.interactor.testConnection(config)
                guard let self else { return }
                let savedID: BackupConfig.ID
                if let configID {
                    interactor.saveUpdate(id: configID, with: config)
                    savedID = configID
                } else {
                    savedID = interactor.saveAdd(config)
                }
                isTesting = false
                testTask = nil
                onClose(savedID)
                // Brief delay so the success haptic punctuates the dismissal
                // animation instead of firing alongside it.
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }
                successFeedbackTrigger &+= 1
            } catch {
                guard let self else { return }
                isTesting = false
                testTask = nil
                if Task.isCancelled { return }
                destination = .errorAlert(
                    message: BackupFileServiceError.connectionTestMessage(for: error)
                )
                // Brief delay so the error haptic punctuates the alert's presentation
                // animation instead of firing alongside it.
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                failureFeedbackTrigger &+= 1
            }
        }
    }

    func onDisappear() {
        testTask?.cancel()
    }
}
