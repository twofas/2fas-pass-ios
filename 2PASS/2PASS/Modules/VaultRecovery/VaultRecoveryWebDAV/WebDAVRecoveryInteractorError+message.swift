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
        case .indexIsDamaged: T.recoveryErrorIndexDamaged
        case .vaultIsDamaged: T.recoveryErrorVaultDamaged
        case .unauthorized: T.recoveryErrorUnauthorized
        case .forbidden: T.recoveryErrorForbidden
        case .indexNotFound: T.recoveryErrorIndexNotFound
        case .vaultNotFound: T.recoveryErrorVaultNotFound
        case .nothingToImport: T.recoveryErrorNothingToImport
        case .urlError(let message): T.loginUriError(message)
        case .syncError(let message):
            {
                if let message {
                    return T.syncStatusErrorGeneralReason(message)
                }
                return T.commonGeneralErrorTryAgain
            }()
        case .networkError(let message): T.generalNetworkErrorDetails(message)
        case .serverError(let message): T.generalServerErrorDetails(message)
        case .sslError: T.syncStatusErrorTlsCertFailed
        case .methodNotAllowed: T.syncStatusErrorNoWebDavServer
        case .schemaNotSupported(let schemeVersion, let expectedSchemeVersion): T.cloudSyncInvalidSchemaErrorMsg(expectedSchemeVersion, schemeVersion)
        }
    }
}
