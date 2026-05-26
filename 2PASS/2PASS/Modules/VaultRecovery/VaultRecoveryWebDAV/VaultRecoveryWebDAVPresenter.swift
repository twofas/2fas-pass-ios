// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI
import Data
import Backup

enum VaultRecoveryWebDAVDestination: RouterDestination {
    case errorAlert(message: String)
    case selectVault(
        BackupIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: (ExchangeVaultVersioned) -> Void
    )

    var id: String {
        switch self {
        case .errorAlert: "errorAlert"
        case .selectVault: "selectVault"
        }
    }
}

@Observable @MainActor
final class VaultRecoveryWebDAVPresenter {

    var url: String = ""
    var allowTLSOff: Bool = false
    var username: String = ""
    var password: String = ""

    private(set) var isFetching: Bool = false

    var destination: VaultRecoveryWebDAVDestination?

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
        return true
    }

    var hasUnsavedChanges: Bool {
        url != (initialConfig?.baseURL ?? "")
            || allowTLSOff != (initialConfig?.allowTLSOff ?? false)
            || username != (initialConfig?.login ?? "")
            || password != (initialConfig?.password ?? "")
    }

    private let interactor: VaultRecoveryWebDAVModuleInteracting
    private let onSelect: (VaultRecoveryData) -> Void

    @ObservationIgnored
    private var fetchTask: Task<Void, Never>?

    @ObservationIgnored
    private var initialConfig: BackupWebDAVConfig?

    init(
        interactor: VaultRecoveryWebDAVModuleInteracting,
        onSelect: @escaping (VaultRecoveryData) -> Void
    ) {
        self.interactor = interactor
        self.onSelect = onSelect

        if let config = interactor.cachedConfig {
            url = config.baseURL
            allowTLSOff = config.allowTLSOff
            username = config.login ?? ""
            password = config.password ?? ""

            initialConfig = config
        }
    }

    func onSave() {
        guard !isFetching else { return }

        guard let normalizedURL = interactor.normalizeURL(url) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorWrongDirectoryUrl))
            return
        }
        guard interactor.isSecureURL(normalizedURL) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorIncorrectUrl))
            return
        }

        isFetching = true

        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let index = try await interactor.recover(
                    baseURL: url,
                    normalizedURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username.isEmpty ? nil : username,
                    password: password.isEmpty ? nil : password
                )
                isFetching = false
                fetchTask = nil
                if Task.isCancelled { return }

                let snapshot = BackupWebDAVConfig(
                    baseURL: url,
                    normalizedURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username.isEmpty ? nil : username,
                    password: password.isEmpty ? nil : password
                )
                interactor.cacheConfig(snapshot)

                initialConfig = snapshot

                destination = .selectVault(
                    index,
                    baseURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username,
                    password: password,
                    onSelect: { [weak self] vault in
                        self?.onSelect(.file(vault, source: .webDAV))
                    }
                )
                
            } catch let error as VaultRecoveryWebDAVError {
                isFetching = false
                fetchTask = nil
                if Task.isCancelled { return }
                destination = .errorAlert(message: error.message)
                
            } catch {
                isFetching = false
                fetchTask = nil
                if Task.isCancelled { return }
                destination = .errorAlert(message: VaultRecoveryWebDAVError.transport(.invalidResponse).message)
            }
        }
    }

    func onDisappear() {
        fetchTask?.cancel()
    }
}
