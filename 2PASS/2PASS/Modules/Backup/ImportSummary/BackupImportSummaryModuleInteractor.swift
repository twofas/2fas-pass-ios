// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol BackupImportSummaryModuleInteracting: AnyObject {
    var defaultVaultID: VaultID { get }
    func listVaults() -> [VaultData]
}

final class BackupImportSummaryModuleInteractor {
    private let vaultsInteractor: VaultsInteracting

    init(vaultsInteractor: VaultsInteracting) {
        self.vaultsInteractor = vaultsInteractor
    }
}

extension BackupImportSummaryModuleInteractor: BackupImportSummaryModuleInteracting {

    var defaultVaultID: VaultID {
        vaultsInteractor.defaultVaultID
    }

    func listVaults() -> [VaultData] {
        vaultsInteractor.listVaults()
    }
}
