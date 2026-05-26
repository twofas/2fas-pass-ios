// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum BackupFileResource: Sendable {
    case index
    case indexLock
    case vault(vaultID: UUID)
    case vaultTemp(vaultID: UUID)
    case vaultDecrypted(vaultID: UUID)

    public var filename: String {
        switch self {
        case .index:
            "index.2faspass"
        case .indexLock:
            "index.2faspass.lock"
        case .vault(let vaultID):
            "\(vaultID.uuidString.lowercased())_v\(Config.webDAVURLSchemaVersion).2faspass"
        case .vaultTemp(let vaultID):
            "\(vaultID.uuidString.lowercased())_v\(Config.webDAVURLSchemaVersion).2faspass.tmp"
        case .vaultDecrypted(let vaultID):
            "\(vaultID.uuidString.lowercased())_v\(Config.webDAVURLSchemaVersion).2faspass-decrypted_ios.json"
        }
    }
}
