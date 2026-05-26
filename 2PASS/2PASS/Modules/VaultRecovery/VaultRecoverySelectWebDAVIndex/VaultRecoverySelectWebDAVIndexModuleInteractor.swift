// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Backup
import Common

protocol VaultRecoverySelectWebDAVIndexModuleInteracting: AnyObject {
    func fetchVault(
        baseURL: URL,
        allowTLSOff: Bool,
        vaultID: VaultID,
        schemeVersion: Int,
        login: String?,
        password: String?
    ) async throws(VaultRecoveryWebDAVError) -> ExchangeVaultVersioned
}

final class VaultRecoverySelectWebDAVIndexModuleInteractor {
    private let recoveryInteractor: BackupSyncRecoveryInteracting

    init(recoveryInteractor: BackupSyncRecoveryInteracting) {
        self.recoveryInteractor = recoveryInteractor
    }
}

extension VaultRecoverySelectWebDAVIndexModuleInteractor: VaultRecoverySelectWebDAVIndexModuleInteracting {

    func fetchVault(
        baseURL: URL,
        allowTLSOff: Bool,
        vaultID: VaultID,
        schemeVersion: Int,
        login: String?,
        password: String?
    ) async throws(VaultRecoveryWebDAVError) -> ExchangeVaultVersioned {
        if schemeVersion > Config.schemaVersion {
            throw .schemaNotSupported(schemeVersion)
        }

        let config = BackupWebDAVConfig(
            baseURL: baseURL.absoluteString,
            normalizedURL: baseURL,
            lockTime: Config.webDAVLockFileTime,
            allowTLSOff: allowTLSOff,
            login: login,
            password: password
        )

        do {
            return try await recoveryInteractor.fetchVault(vaultID: vaultID, config)
        } catch {
            switch error {
            case .transport(let transportError):
                if case .notFound = transportError {
                    throw VaultRecoveryWebDAVError.vaultNotFound
                }
                throw VaultRecoveryWebDAVError.transport(transportError)
            case .schemaNotSupported(let version):
                throw VaultRecoveryWebDAVError.schemaNotSupported(version)
            case .vaultIsDamaged:
                throw VaultRecoveryWebDAVError.vaultIsDamaged
            }
        }
    }
}
