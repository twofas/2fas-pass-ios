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
        // Pre-flight schema check before any network I/O — index entries carry the schema
        // version, so we can reject incompatible vaults without downloading them. The
        // post-fetch schema check inside the container catches drift between the index and
        // the actual vault file (rare but possible).
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
            // Single `catch` + inner `switch` — same typed-throws idiom used in
            // `VaultRecoveryWebDAVModuleInteractor.recover`. Both `VaultRecoveryWebDAVError`
            // and `BackupVaultFetchError` share `.transport`/`.schemaNotSupported` case
            // names, so qualified throws inside the switch keep the inference unambiguous.
            switch error {
            case .transport(let transportError):
                // Vault-fetch 404 means the index pointed at a vault that no longer exists on
                // the server — distinct from the index-fetch 404 in
                // `VaultRecoveryWebDAVModuleInteractor` ("no index at this URL yet").
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
