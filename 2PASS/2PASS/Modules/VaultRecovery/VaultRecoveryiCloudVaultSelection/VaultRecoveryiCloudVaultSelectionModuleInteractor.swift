// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol VaultRecoveryiCloudVaultSelectionModuleInteracting: AnyObject {
    func listVaultsToRecover() async throws -> [VaultRawData]
    func deleteVault(id: VaultID) async throws
}

final class VaultRecoveryiCloudVaultSelectionModuleInteractor {
    private let recoveryInteractor: BackupSyncRecoveryInteracting

    init(recoveryInteractor: BackupSyncRecoveryInteracting) {
        self.recoveryInteractor = recoveryInteractor
    }
}

extension VaultRecoveryiCloudVaultSelectionModuleInteractor: VaultRecoveryiCloudVaultSelectionModuleInteracting {
    func listVaultsToRecover() async throws -> [VaultRawData] {
        try await recoveryInteractor.listICloudVaultsToRecover()
    }

    func deleteVault(id: VaultID) async throws {
        try await recoveryInteractor.deleteICloudVault(id: id)
    }
}
