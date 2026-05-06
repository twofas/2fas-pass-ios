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
            return String(localized: .connectionTestErrorUnauthorized)
        case .forbidden:
            return String(localized: .connectionTestErrorForbidden)
        case .notFound:
            return String(localized: .connectionTestErrorNotFound)
        case .methodNotAllowed:
            return String(localized: .connectionTestErrorMethodNotAllowed)
        case .unexpectedStatus(let code):
            return String(localized: .connectionTestErrorUnexpectedStatus(code))
        case .ssl:
            return String(localized: .connectionTestErrorSsl)
        case .network:
            return String(localized: .connectionTestErrorNetwork)
        case .server:
            return String(localized: .connectionTestErrorServer)
        case .url:
            return String(localized: .connectionTestErrorUrl)
        case .invalidResponse:
            return String(localized: .connectionTestErrorInvalidResponse)
        }
    }
}
