// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data
import Backup

/// Identifies the transport that produced a recovered vault file. Carried alongside the
/// parsed `ExchangeVaultVersioned` so the recover step can persist the corresponding config
/// — but only after items are actually committed to local storage.
///
/// Tag-only: the actual credentials live in the recovery cache (`VaultRecoveryCacheInteractor`,
/// backed by `MainRepository`'s in-memory recovery-cache slots). The producer presenter
/// writes the typed config via `interactor.cacheConfig(_:)`; the cache JSON-encodes and
/// AES-GCM-encrypts under the Secure-Enclave appKey internally.
/// `VaultRecoveryRecoverModuleInteractor.persistRecoverySource(_:)` reads back via
/// `cacheInteractor.cachedS3Config` / `.cachedWebDAVConfig` when this enum's case tells it
/// which slot to consult.
///
/// `.localFile` is an explicit "no remote credentials to persist" marker (file picker, local
/// backup import). Modeled as a case rather than an optional so that adding a new transport
/// forces every call site to acknowledge what kind of source produced its vault.
enum VaultRecoveryFileSource: Sendable {
    case webDAV
    case s3
    case localFile
}

enum VaultRecoveryData {
    case file(ExchangeVaultVersioned, source: VaultRecoveryFileSource)
    case cloud(VaultRawData)
    case localVault
}

extension VaultRecoveryData {

    var vaultSeedHash: String? {
        switch self {
        case .file(let vault, _):
            vault.encryption?.seedHash
        case .cloud(let vaultData):
            vaultData.seedHash
        case .localVault:
            nil
        }
    }

    var vaultID: UUID? {
        switch self {
        case .file(let vault, _):
            UUID(uuidString: vault.vaultID)
        case .cloud(let vaultData):
            vaultData.vaultID
        case .localVault:
            nil
        }
    }
}
