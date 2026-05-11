// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit
import Common
import Data
import Backup

enum VaultRecoverySelectS3IndexDestination: Identifiable {
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
final class VaultRecoverySelectS3IndexPresenter {
    let backups: [BackupIndexEntry]
    private let index: BackupIndex

    var selectedVaultID: String?

    var destination: VaultRecoverySelectS3IndexDestination?

    private let interactor: VaultRecoverySelectS3IndexModuleInteracting
    private let config: S3ServiceConfig
    private let onSelect: (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void

    init(
        interactor: VaultRecoverySelectS3IndexModuleInteracting,
        index: BackupIndex,
        config: S3ServiceConfig,
        onSelect: @escaping (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void
    ) {
        self.interactor = interactor
        self.index = index
        self.backups = index.backups.sorted { $0.vaultUpdatedAt > $1.vaultUpdatedAt }
        self.config = config
        self.onSelect = onSelect
    }
}

extension VaultRecoverySelectS3IndexPresenter {
    func onSelectVault(_ vault: BackupIndexEntry) {
        guard selectedVaultID == nil else { return }
        selectedVaultID = vault.vaultId

        guard let uuid = UUID(uuidString: vault.vaultId) else {
            Log("VaultRecoverySelectS3IndexPresenter - incorrect UUID", severity: .error)
            selectedVaultID = nil
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let exchangeVault = try await interactor.fetchVault(
                    config: config,
                    vaultID: uuid,
                    schemeVersion: vault.schemaVersion
                )
                // Build the source-config now (we have all the credentials and the picked
                // vault id), but DON'T persist yet — `VaultRecoveryRecoverModuleInteractor`
                // will save it only after items are actually committed to local storage.
                let source = VaultRecoveryFileSource.s3(config)
                onSelect(exchangeVault, source)
            } catch let error as VaultRecoveryS3Error {
                self.showStatus(error)
            } catch {
                self.showStatus(.transport(.invalidResponse))
            }
        }
    }

    private func showStatus(_ status: VaultRecoveryS3Error) {
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
