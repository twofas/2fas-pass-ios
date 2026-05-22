// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

/// Recovery-flow outcomes for the S3 presenters. Kept separate from
/// `VaultRecoveryWebDAVError` so each backend owns its user-facing strings.
enum VaultRecoveryS3Error: Error {
    case transport(BackupFileServiceError)
    case indexNotFound
    case vaultNotFound
    case indexIsDamaged
    case vaultIsDamaged
    case schemaNotSupported(Int)
}

extension VaultRecoveryS3Error {
    /// Reuses the WebDAV recovery strings — wording is transport-agnostic.
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

    /// `.notFound` is unreachable from this path — interactors rethrow it as
    /// `.indexNotFound` / `.vaultNotFound` before this mapping runs.
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
