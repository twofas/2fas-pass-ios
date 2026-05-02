// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit
import Common
import Data
import Backup

enum VaultRecoverySelectWebDAVIndexDestination: Identifiable {
    var id: String {
        switch self {
        case .selectRecoveryKey: "selectRecoveryKey"
        case .error: "error"
        case .appUpdateNeeded: "appUpdateNeeded"
        }
    }

    case selectRecoveryKey(ExchangeVaultVersioned, onClose: Callback)
    case error(message: String, onClose: Callback)
    case appUpdateNeeded(schemaVersion: Int, onUpdate: Callback, onClose: Callback)
}

@Observable
final class VaultRecoverySelectWebDAVIndexPresenter {
    let backups: [BackupIndexEntry]
    private let index: BackupIndex

    var isLoading = false

    var destination: VaultRecoverySelectWebDAVIndexDestination?

    private let interactor: VaultRecoverySelectWebDAVIndexModuleInteracting
    private let baseURL: URL
    private let allowTLSOff: Bool
    private let login: String?
    private let password: String?
    private let onSelect: (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void

    init(
        interactor: VaultRecoverySelectWebDAVIndexModuleInteracting,
        index: BackupIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: @escaping (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void,
    ) {
        self.interactor = interactor
        self.index = index
        self.backups = index.backups.sorted { $0.vaultUpdatedAt > $1.vaultUpdatedAt }
        self.baseURL = baseURL
        self.allowTLSOff = allowTLSOff
        self.login = login
        self.password = password
        self.onSelect = onSelect
    }
}

extension VaultRecoverySelectWebDAVIndexPresenter {
    func onSelectVault(_ vault: BackupIndexEntry) {
        isLoading = true

        guard let uuid = UUID(uuidString: vault.vaultId) else {
            Log("VaultRecoverySelectWebDAVIndexPresenter - incorrect UUID", severity: .error)
            isLoading = false
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let exchangeVault = try await interactor.fetchVault(
                    baseURL: baseURL,
                    allowTLSOff: allowTLSOff,
                    vaultID: uuid,
                    schemeVersion: vault.schemaVersion,
                    login: login,
                    password: password
                )
                // Build the source-config now (we have all the credentials and the picked
                // vault id), but DON'T persist yet — `VaultRecoveryRecoverModuleInteractor`
                // will save it only after items are actually committed to local storage,
                // closing the regression where credentials persisted on `fetchVault` success
                // and leaked through every subsequent flow abort.
                let source = VaultRecoveryFileSource.webDAV(
                    BackupWebDAVConfig(
                        baseURL: baseURL.absoluteString,
                        normalizedURL: baseURL,
                        lockTime: Config.webDAVLockFileTime,
                        allowTLSOff: allowTLSOff,
                        login: login,
                        password: password
                    )
                )
                onSelect(exchangeVault, source)
            } catch let error as VaultRecoveryWebDAVError {
                self.showStatus(error)
            } catch {
                self.showStatus(.transport(.invalidResponse))
            }
        }
    }

    private func showStatus(_ status: VaultRecoveryWebDAVError) {
        isLoading = false

        switch status {
        case .schemaNotSupported(let schemaVersion):
            destination = .appUpdateNeeded(
                schemaVersion: schemaVersion,
                onUpdate: { [weak self] in
                    self?.onUpdateApp()
                },
                onClose: { [weak self] in
                    self?.destination = nil
                }
            )
        default:
            showError(status.message)
        }
    }

    func showError(_ message: String) {
        destination = .error(message: message, onClose: { [weak self] in
            self?.destination = nil
        })
    }

    private func onUpdateApp() {
        UIApplication.shared.open(Config.appStoreURL)
    }
}
