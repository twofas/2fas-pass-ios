// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit
import Common
import Data

enum VaultRecoverySelectWebDAVIndexDestination: Identifiable {
    var id: String {
        switch self {
        case .selectRecoveryKey: "selectRecoveryKey"
        case .error: "error"
        case .appUpdateNeeded: "appUpdateNeeded"
        }
    }
    
    case selectRecoveryKey(ExchangeVault, onClose: Callback)
    case error(message: String, onClose: Callback)
    case appUpdateNeeded(schemaVersion: Int, onUpdate: Callback, onClose: Callback)
}

@Observable
final class VaultRecoverySelectWebDAVIndexPresenter {
    let backups: [WebDAVIndexEntry]
    private let index: WebDAVIndex
   
    var isLoading = false
    
    var destination: VaultRecoverySelectWebDAVIndexDestination?
    
    private let interactor: VaultRecoverySelectWebDAVIndexModuleInteracting
    private let baseURL: URL
    private let allowTLSOff: Bool
    private let login: String?
    private let password: String?
    private let onSelect: (ExchangeVault) -> Void
    
    init(
        interactor: VaultRecoverySelectWebDAVIndexModuleInteracting,
        index: WebDAVIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: @escaping (ExchangeVault) -> Void,
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
    func onSelectVault(_ vault: WebDAVIndexEntry) {
        isLoading = true
        
        guard let uuid = UUID(uuidString: vault.vaultId) else {
            Log("VaultRecoverySelectWebDAVIndexPresenter - incorrect UUID", severity: .error)
            isLoading = false
            return
        }
        
        interactor.fetchVault(
            baseURL: baseURL,
            allowTLSOff: allowTLSOff,
            vaultID: uuid,
            schemeVersion: vault.schemaVersion,
            login: login,
            password: password
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let exchangeVault):
                interactor
                    .saveConfiguration(
                        baseURL: baseURL,
                        allowTLSOff: allowTLSOff,
                        vaultID: uuid,
                        login: login,
                        password: password
                    )
                onSelect(exchangeVault)
            case .failure(let status):
                showStatus(status)
            }
        }
    }
    
    private func showStatus(_ status: WebDAVRecoveryInteractorError) {
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
