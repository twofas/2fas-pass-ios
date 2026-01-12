// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

extension WebDAVRecoveryInteractorError {
    var message: String {
        switch self {
        case .indexIsDamaged: String(localized: .recoveryErrorIndexDamaged)
        case .vaultIsDamaged: String(localized: .recoveryErrorVaultDamaged)
        case .unauthorized: String(localized: .recoveryErrorUnauthorized)
        case .forbidden: String(localized: .recoveryErrorForbidden)
        case .indexNotFound: String(localized: .recoveryErrorIndexNotFound)
        case .vaultNotFound: String(localized: .recoveryErrorVaultNotFound)
        case .nothingToImport: String(localized: .recoveryErrorNothingToImport)
        case .urlError(let message): String(localized: .loginUriError(message))
        case .syncError(let message):
            {
                if let message {
                    return String(localized: .syncStatusErrorGeneralReason(message))
                }
                return String(localized: .commonGeneralErrorTryAgain)
            }()
        case .networkError(let message): String(localized: .generalNetworkErrorDetails(message))
        case .serverError(let message): String(localized: .generalServerErrorDetails(message))
        case .sslError: String(localized: .syncStatusErrorTlsCertFailed)
        case .methodNotAllowed: String(localized: .syncStatusErrorNoWebDavServer)
        case .schemaNotSupported(let schemaVersion): String(localized: .cloudSyncInvalidSchemaErrorMsg(Int32(schemaVersion)))
        }
    }
}
