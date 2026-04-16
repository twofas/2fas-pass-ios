// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol TransferItemsFileSummaryModuleInteracting: AnyObject {
    var defaultVaultID: VaultID { get }
    func listVaults() -> [VaultData]
}

final class TransferItemsFileSummaryModuleInteractor: TransferItemsFileSummaryModuleInteracting {

    private let vaultsInteractor: VaultsInteracting

    init(vaultsInteractor: VaultsInteracting) {
        self.vaultsInteractor = vaultsInteractor
    }

    var defaultVaultID: VaultID {
        vaultsInteractor.defaultVaultID
    }

    func listVaults() -> [VaultData] {
        vaultsInteractor.listVaults()
    }
}
