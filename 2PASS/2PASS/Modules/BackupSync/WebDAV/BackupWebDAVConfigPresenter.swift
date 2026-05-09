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
    case dismiss

    var id: String { "dismiss" }
}

@Observable @MainActor
final class BackupWebDAVConfigPresenter {

    var url: String = ""
    var allowTLSOff = false
    var username: String = ""
    var password: String = ""

    var uriError: String?
    /// Set to a localized error string when the connection probe fails. Cleared on every new
    /// `onSave()` attempt. Distinct from `uriError`, which is for synchronous field validation;
    /// `connectionError` is for asynchronous probe failures from the Backup framework.
    var connectionError: String?
    /// `true` while the probe is in flight. Drives the button's disabled state and spinner.
    private(set) var isTesting: Bool = false
    var destination: BackupWebDAVConfigDestination?

    let isEditMode: Bool

    private let interactor: BackupWebDAVConfigModuleInteracting
    private let configID: UUID?
    /// Called on save (with the saved config's UUID) or programmatic close (with `nil`).
    /// Toolbar Cancel goes through `\.dismiss` directly and bypasses this callback.
    private let onClose: (UUID?) -> Void

    init(interactor: BackupWebDAVConfigModuleInteracting, configID: UUID?, onClose: @escaping (UUID?) -> Void) {
        self.interactor = interactor
        self.configID = configID
        self.onClose = onClose
        self.isEditMode = configID != nil
    }

    func onAppear() {
        guard let existing = interactor.existingConfig else { return }
        url = existing.baseURL
        allowTLSOff = existing.allowTLSOff
        username = existing.login ?? ""
        password = existing.password ?? ""
    }

    func onSave() {
        guard !isTesting else { return }

        guard let normalizedURL = interactor.normalizeURL(url) else {
            uriError = String(localized: .syncStatusErrorWrongDirectoryUrl)
            connectionError = nil
            return
        }

        guard interactor.isSecureURL(normalizedURL) else {
            uriError = String(localized: .syncStatusErrorIncorrectUrl)
            connectionError = nil
            return
        }

        let config = BackupWebDAVConfig(
            baseURL: url,
            normalizedURL: normalizedURL,
            allowTLSOff: allowTLSOff,
            login: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password
        )

        uriError = nil
        connectionError = nil
        isTesting = true

        Task { [weak self] in
            do {
                try await self?.interactor.testConnection(config)
                guard let self else { return }
                let savedID: UUID
                if let configID {
                    interactor.saveUpdate(id: configID, with: config)
                    savedID = configID
                } else {
                    savedID = interactor.saveAdd(config)
                }
                isTesting = false
                onClose(savedID)
            } catch {
                guard let self else { return }
                connectionError = BackupFileServiceError.connectionTestMessage(for: error)
                isTesting = false
            }
        }
    }
}
