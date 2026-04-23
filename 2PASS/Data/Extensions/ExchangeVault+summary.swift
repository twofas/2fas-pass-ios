// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public extension ExchangeVault {
    var summary: (date: Date, vaultName: String, deviceName: String?, itemsCount: Int) {
        (
            date: Date(exportTimestamp: vault.updatedAt),
            vaultName: vault.name,
            deviceName: origin.deviceName,
            itemsCount: itemsCount
        )
    }
}

public extension ExchangeVaultVersioned {
    var summary: (date: Date, vaultName: String, deviceName: String?, itemsCount: Int) {
        switch self {
        case .v1(let vault):
            return (
                date: Date(exportTimestamp: vault.vault.updatedAt),
                vaultName: vault.vault.name,
                deviceName: vault.origin.deviceName,
                itemsCount: vault.itemsCount
            )
        case .v2(let vault):
            return vault.summary
        }
    }
}
