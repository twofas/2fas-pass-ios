// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data
import Backup

enum VaultRecoveryWebDAVDestination: Identifiable {
    var id: String {
        switch self {
        case .selectVault: "selectVault"
        case .select: "select"
        case .error: "error"
        }
    }

    case selectVault(
        BackupIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void
    )
    case select(VaultRecoveryData, onClose: Callback)
    case error(message: String, onClose: Callback)
}

@Observable
final class VaultRecoveryWebDAVPresenter {

    var url: String = ""
    var allowTLSOff: Bool = false
    var username: String = ""
    var password: String = ""

    var isLoading = false

    var destination: VaultRecoveryWebDAVDestination?

    private let interactor: VaultRecoveryWebDAVModuleInteracting

    init(
        interactor: VaultRecoveryWebDAVModuleInteracting
    ) {
        self.interactor = interactor
    }
}

extension VaultRecoveryWebDAVPresenter {

    func onConnect() {
        isLoading = true

        guard let normalizedURL = interactor.normalizeURL(url) else {
            showError(String(localized: .syncStatusErrorWrongDirectoryUrl))
            isLoading = false
            return
        }

        guard interactor.isSecureURL(normalizedURL) else {
            showError("Unsecure URL!")
            isLoading = false
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let index = try await interactor.recover(
                    baseURL: url,
                    normalizedURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username,
                    password: password
                )
                self.isLoading = false
                self.destination = .selectVault(
                    index,
                    baseURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username,
                    password: password,
                    onSelect: { [weak self] vault, source in
                        self?.destination = nil

                        Task {
                            try await Task.sleep(for: .milliseconds(700))
                            guard let self else { return }

                            self.destination = .select(.file(vault, source: source), onClose: { [weak self] in
                                self?.destination = nil
                            })
                        }
                    }
                )
            } catch let error as VaultRecoveryWebDAVError {
                self.showStatus(error)
            } catch {
                // Typed throws on a protocol erase to `any Error` at the Task boundary; the
                // catch above handles every realistic case, but a defensive fallback keeps
                // the UI responsive if a future change introduces a new error type.
                self.showStatus(.transport(.invalidResponse))
            }
        }
    }

    private func showStatus(_ status: VaultRecoveryWebDAVError) {
        isLoading = false
        showError(status.message)
    }

    func showError(_ message: String) {
        destination = .error(message: message, onClose: { [weak self] in
            self?.destination = nil
        })
    }
}
