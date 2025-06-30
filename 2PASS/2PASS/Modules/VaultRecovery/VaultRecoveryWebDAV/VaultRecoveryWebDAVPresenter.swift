// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data

enum VaultRecoveryWebDAVDestination: Identifiable {
    var id: String {
        switch self {
        case .selectVault: "selectVault"
        case .select: "select"
        case .error: "error"
        }
    }
    
    case selectVault(
        WebDAVIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: (ExchangeVault) -> Void
    )
    case select(VaultRecoveryData)
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
            showError(T.syncStatusErrorWrongDirectoryUrl)
            isLoading = false
            return
        }
        
        guard interactor.isSecureURL(normalizedURL) else {
            showError("Unsecure URL!")
            isLoading = false
            return
        }
                
        interactor.recover(
            baseUrl: url,
            normalizedURL: normalizedURL,
            allowTLSOff: allowTLSOff,
            login: username,
            password: password
        ) { [weak self] result in
            guard let self else { return }
            
            self.isLoading = false
            
            switch result {
            case .success(let index):
                destination = .selectVault(
                    index,
                    baseURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username,
                    password: password,
                    onSelect: { [weak self] vault in
                        self?.destination = nil
                        
                        Task {
                            try await Task.sleep(for: .milliseconds(700))
                            guard let self else { return }
                            
                            self.destination = .select(.file(vault))
                        }
                    }
                )
            case .failure(let status):
                showStatus(status)
            }
        }
    }
    
    private func showStatus(_ status: WebDAVRecoveryInteractorError) {
        isLoading = false
        showError(status.message)
    }
    
    func showError(_ message: String) {
        destination = .error(message: message, onClose: { [weak self] in
            self?.destination = nil
        })
    }
}
