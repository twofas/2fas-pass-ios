// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

/// Surfaces recovery-flow outcomes to the two S3 recovery presenters
/// (`VaultRecoveryS3Presenter`, `VaultRecoverySelectS3IndexPresenter`).
///
/// Same shape as `VaultRecoveryWebDAVError` — both file-based backends share the underlying
/// `BackupFileServiceError` transport layer, schema-mismatch outcomes, and "did the missing
/// file mean the index or the vault is missing?" disambiguation. Kept as a sibling type so
/// each module owns the strings shown to the user (S3-specific wording can diverge later
/// without dragging WebDAV along).
enum VaultRecoveryS3Error: Error {
    case transport(BackupFileServiceError)
    case indexNotFound
    case vaultNotFound
    case indexIsDamaged
    case vaultIsDamaged
    case schemaNotSupported(Int)
}

extension VaultRecoveryS3Error {
    /// Localized message for an alert. Reuses the WebDAV recovery strings — both backends are
    /// file-based and the user-facing wording is transport-agnostic. If S3-specific wording
    /// becomes useful, swap individual cases to dedicated `recoveryErrorS3*` strings.
    var message: String {
        switch self {
        case .transport(let inner):
            return Self.message(for: inner)
        case .indexIsDamaged:
            return String(localized: .recoveryErrorIndexDamaged)
        case .vaultIsDamaged:
            return String(localized: .recoveryErrorVaultDamaged)
        case .indexNotFound:
            return String(localized: .recoveryErrorIndexNotFound)
        case .vaultNotFound:
            return String(localized: .recoveryErrorVaultNotFound)
        case .schemaNotSupported:
            return String(localized: .cloudSyncInvalidSchemaErrorMsg)
        }
    }

    /// Same transport mapping as the WebDAV equivalent. `.notFound` is unreachable from this
    /// path — the module interactors catch it and rethrow as `.indexNotFound` /
    /// `.vaultNotFound` before this mapping runs.
    private static func message(for transport: BackupFileServiceError) -> String {
        switch transport {
        case .unauthorized:
            return String(localized: .recoveryErrorUnauthorized)
        case .forbidden:
            return String(localized: .recoveryErrorForbidden)
        case .methodNotAllowed:
            return String(localized: .syncStatusErrorNoWebDavServer)
        case .ssl:
            return String(localized: .syncStatusErrorTlsCertFailed)
        case .network(let underlying):
            return String(localized: .generalNetworkErrorDetails(underlying.localizedDescription))
        case .server(let underlying):
            return String(localized: .generalServerErrorDetails(underlying.localizedDescription))
        case .url(let underlying):
            return String(localized: .loginUriError(underlying.localizedDescription))
        case .unexpectedStatus(let code):
            return String(localized: .syncStatusErrorGeneralReason("HTTP \(code)"))
        case .invalidResponse:
            return String(localized: .commonGeneralErrorTryAgain)
        case .notFound:
            return String(localized: .commonGeneralErrorTryAgain)
        }
    }
}
