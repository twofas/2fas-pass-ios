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
