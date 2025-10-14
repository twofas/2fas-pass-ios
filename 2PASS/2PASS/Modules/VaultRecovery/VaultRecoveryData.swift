// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data

enum VaultRecoveryData {
    case file(ExchangeVaultVersioned)
    case cloud(VaultRawData)
    case localVault
}

extension VaultRecoveryData {

    var vaultSeedHash: String? {
        switch self {
        case .file(let vault):
            vault.encryption?.seedHash
        case .cloud(let vaultData):
            vaultData.seedHash
        case .localVault:
            nil
        }
    }
    
    var vaultID: UUID? {
        switch self {
        case .file(let vault):
            UUID(uuidString: vault.vaultID)
        case .cloud(let vaultData):
            vaultData.vaultID
        case .localVault:
            nil
        }
    }
}
