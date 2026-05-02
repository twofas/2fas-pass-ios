// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

extension VaultRecoveryWebDAVError {
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
        case .nothingToImport:
            return String(localized: .recoveryErrorNothingToImport)
        case .schemaNotSupported:
            return String(localized: .cloudSyncInvalidSchemaErrorMsg)
        }
    }

    /// Maps the new transport-layer enum onto the same localized strings the legacy
    /// `WebDAVRecoveryInteractorError+message` extension used. `.notFound` is intentionally
    /// absent — the call sites in the module interactors catch it and rethrow as
    /// `.indexNotFound` / `.vaultNotFound` before this mapping ever runs.
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
            // Should be unreachable — the module interactors catch this and rethrow as
            // `.indexNotFound` / `.vaultNotFound`. Falling back to the generic message keeps
            // us from crashing if a future call site forgets to catch it.
            return String(localized: .commonGeneralErrorTryAgain)
        }
    }
}
