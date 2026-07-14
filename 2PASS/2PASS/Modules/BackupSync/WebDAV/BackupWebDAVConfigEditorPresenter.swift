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

enum BackupWebDAVConfigEditorDestination: RouterDestination {
    case errorAlert(message: String)

    var id: String {
        switch self {
        case .errorAlert: "errorAlert"
        }
    }
}

@Observable @MainActor
final class BackupWebDAVConfigEditorPresenter {

    var url: String = ""
    var allowTLSOff = false
    var username: String = ""
    var password: String = ""

    private(set) var isTesting: Bool = false

    private(set) var successFeedbackTrigger: Int = 0
    private(set) var failureFeedbackTrigger: Int = 0

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

    var destination: BackupWebDAVConfigEditorDestination?

    let isEditMode: Bool

    private let interactor: BackupWebDAVConfigEditorModuleInteracting
    private let configID: BackupConfig.ID?
    private let onClose: @MainActor (BackupConfig.ID?) -> Void

    @ObservationIgnored
    private var testTask: Task<Void, Never>?

    @ObservationIgnored
    private var originalSnapshot: BackupWebDAVConfig?

    init(interactor: BackupWebDAVConfigEditorModuleInteracting, configID: BackupConfig.ID?, onClose: @escaping @MainActor (BackupConfig.ID?) -> Void) {
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

                let savedID = interactor.save(config)
                isTesting = false
                testTask = nil
                onClose(savedID)

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
