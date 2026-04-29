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
    private let onClose: Callback

    init(interactor: BackupWebDAVConfigModuleInteracting, configID: UUID?, onClose: @escaping Callback) {
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
                if let configID {
                    interactor.saveUpdate(id: configID, with: config)
                } else {
                    interactor.saveAdd(config)
                }
                isTesting = false
                onClose()
            } catch {
                guard let self else { return }
                connectionError = Self.errorMessage(for: error)
                isTesting = false
            }
        }
    }
}

private extension BackupWebDAVConfigPresenter {
    /// Maps probe failures to localized strings. The Task closure erases typed throws to
    /// `any Error`, so we accept that and downcast — falling back to a generic error string
    /// if a non-`BackupFileServiceError` somehow leaks through. `.notFound` is folded into
    /// the success path inside `BackupFileServiceSession.testConnection` so it shouldn't
    /// reach here, but the case is handled defensively.
    static func errorMessage(for error: any Error) -> String {
        guard let error = error as? BackupFileServiceError else {
            return String(localized: .commonError)
        }
        switch error {
        case .unauthorized:
            return String(localized: .connectionTestErrorUnauthorized)
        case .forbidden:
            return String(localized: .connectionTestErrorForbidden)
        case .notFound:
            return String(localized: .connectionTestErrorNotFound)
        case .methodNotAllowed:
            return String(localized: .connectionTestErrorMethodNotAllowed)
        case .unexpectedStatus(let code):
            return String(localized: .connectionTestErrorUnexpectedStatus(code))
        case .ssl:
            return String(localized: .connectionTestErrorSsl)
        case .network:
            return String(localized: .connectionTestErrorNetwork)
        case .server:
            return String(localized: .connectionTestErrorServer)
        case .url:
            return String(localized: .connectionTestErrorUrl)
        case .invalidResponse:
            return String(localized: .connectionTestErrorInvalidResponse)
        }
    }
}
