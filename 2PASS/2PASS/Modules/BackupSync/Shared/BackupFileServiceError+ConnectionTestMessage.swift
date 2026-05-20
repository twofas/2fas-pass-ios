// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

extension BackupFileServiceError {
    static func connectionTestMessage(for error: any Error) -> String {
        guard let error = error as? BackupFileServiceError else {
            return String(localized: .commonError)
        }
        switch error {
        case .unauthorized:
            return String(localized: .syncStatusErrorNotAuthorized)
        case .forbidden:
            return String(localized: .syncStatusErrorUserIsForbidden)
        case .notFound:
            return String(localized: .syncErrorNotFound)
        case .methodNotAllowed:
            return String(localized: .syncStatusErrorMethodNotAllowed)
        case .unexpectedStatus(let code):
            return String(localized: .syncStatusErrorGeneralReason("HTTP \(code)"))
        case .ssl:
            return String(localized: .syncStatusErrorSslError)
        case .network:
            return String(localized: .syncErrorNetwork)
        case .server:
            return String(localized: .syncErrorServer)
        case .url:
            return String(localized: .syncStatusErrorIncorrectUrl)
        case .invalidResponse:
            return String(localized: .syncErrorInvalidResponse)
        }
    }
}
