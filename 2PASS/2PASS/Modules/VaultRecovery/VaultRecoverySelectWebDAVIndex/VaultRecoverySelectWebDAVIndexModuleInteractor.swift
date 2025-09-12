// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol VaultRecoverySelectWebDAVIndexModuleInteracting: AnyObject {
    func fetchVault(
        baseURL: URL,
        allowTLSOff: Bool,
        vaultID: VaultID,
        schemeVersion: Int,
        login: String?,
        password: String?,
        completion: @escaping (Result<ExchangeVault, WebDAVRecoveryInteractorError>) -> Void
    )
    func saveConfiguration(
        baseURL: URL,
        allowTLSOff: Bool,
        vaultID: VaultID,
        login: String?,
        password: String?
    )
}

final class VaultRecoverySelectWebDAVIndexModuleInteractor {
    private let webDAVRecoveryInteractor: WebDAVRecoveryInteracting
    
    init(webDAVRecoveryInteractor: WebDAVRecoveryInteracting) {
        self.webDAVRecoveryInteractor = webDAVRecoveryInteractor
    }
}

extension VaultRecoverySelectWebDAVIndexModuleInteractor: VaultRecoverySelectWebDAVIndexModuleInteracting {
    func fetchVault(
        baseURL: URL,
        allowTLSOff: Bool,
        vaultID: VaultID,
        schemeVersion: Int,
        login: String?,
        password: String?,
        completion: @escaping (Result<ExchangeVault, WebDAVRecoveryInteractorError>) -> Void
    ) {
        webDAVRecoveryInteractor.fetchVault(
            baseURL: baseURL,
            allowTLSOff: allowTLSOff,
            vaultID: vaultID,
            schemeVersion: schemeVersion,
            login: login,
            password: password,
            completion: completion
        )
    }
    
    func saveConfiguration(
        baseURL: URL,
        allowTLSOff: Bool,
        vaultID: VaultID,
        login: String?,
        password: String?
    ) {
        webDAVRecoveryInteractor.saveConfiguration(
            baseURL: baseURL,
            allowTLSOff: allowTLSOff,
            vaultID: vaultID,
            login: login,
            password: password
        )
    }
}

