// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Backup
import Common

protocol VaultRecoverySelectS3IndexModuleInteracting: AnyObject {
    func fetchVault(
        config: S3ServiceConfig,
        vaultID: VaultID,
        schemeVersion: Int
    ) async throws(VaultRecoveryS3Error) -> ExchangeVaultVersioned
}

final class VaultRecoverySelectS3IndexModuleInteractor {
    private let recoveryInteractor: BackupSyncRecoveryInteracting

    init(recoveryInteractor: BackupSyncRecoveryInteracting) {
        self.recoveryInteractor = recoveryInteractor
    }
}

extension VaultRecoverySelectS3IndexModuleInteractor: VaultRecoverySelectS3IndexModuleInteracting {

    func fetchVault(
        config: S3ServiceConfig,
        vaultID: VaultID,
        schemeVersion: Int
    ) async throws(VaultRecoveryS3Error) -> ExchangeVaultVersioned {
        // Pre-flight schema check before any network I/O — index entries carry the schema
        // version, so we can reject incompatible vaults without downloading them. The
        // post-fetch schema check inside the container catches drift between the index and
        // the actual vault file (rare but possible).
        if schemeVersion > Config.schemaVersion {
            throw .schemaNotSupported(schemeVersion)
        }

        do {
            return try await recoveryInteractor.fetchVault(vaultID: vaultID, config)
        } catch {
            // Single `catch` + inner `switch` — same typed-throws idiom used in
            // `VaultRecoverySelectWebDAVIndexModuleInteractor.fetchVault`.
            switch error {
            case .transport(let transportError):
                // Vault-fetch 404 means the index pointed at a vault that no longer exists in
                // the bucket — distinct from the index-fetch 404 in
                // `VaultRecoveryS3ModuleInteractor` ("no index in this bucket yet").
                if case .notFound = transportError {
                    throw VaultRecoveryS3Error.vaultNotFound
                }
                throw VaultRecoveryS3Error.transport(transportError)
            case .schemaNotSupported(let version):
                throw VaultRecoveryS3Error.schemaNotSupported(version)
            case .vaultIsDamaged:
                throw VaultRecoveryS3Error.vaultIsDamaged
            }
        }
    }
}
