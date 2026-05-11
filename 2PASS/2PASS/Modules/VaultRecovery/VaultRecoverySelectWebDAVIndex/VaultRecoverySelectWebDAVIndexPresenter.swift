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

    var selectedVaultID: String?

    var destination: VaultRecoverySelectWebDAVIndexDestination?

    private let interactor: VaultRecoverySelectWebDAVIndexModuleInteracting
    private let baseURL: URL
    private let allowTLSOff: Bool
    private let login: String?
    private let password: String?
    private let onSelect: (ExchangeVaultVersioned) -> Void

    init(
        interactor: VaultRecoverySelectWebDAVIndexModuleInteracting,
        index: BackupIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: @escaping (ExchangeVaultVersioned) -> Void,
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
        guard selectedVaultID == nil else { return }
        selectedVaultID = vault.vaultId

        guard let uuid = UUID(uuidString: vault.vaultId) else {
            Log("VaultRecoverySelectWebDAVIndexPresenter - incorrect UUID", severity: .error)
            selectedVaultID = nil
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
                // The encrypted source is wrapped by `VaultRecoveryWebDAVPresenter` (which
                // owns the encryption seam); this presenter just hands the picked vault upward.
                onSelect(exchangeVault)
            } catch let error as VaultRecoveryWebDAVError {
                self.showStatus(error)
            } catch {
                self.showStatus(.transport(.invalidResponse))
            }
        }
    }

    private func showStatus(_ status: VaultRecoveryWebDAVError) {
        selectedVaultID = nil

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
