// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol VaultRecoveryiCloudVaultSelectionModuleInteracting: AnyObject {
    func listVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void)
}

final class VaultRecoveryiCloudVaultSelectionModuleInteractor {
    private let cloudRecoveryInteractor: CloudRecoveryInteracting
    
    init(cloudRecoveryInteractor: CloudRecoveryInteracting) {
        self.cloudRecoveryInteractor = cloudRecoveryInteractor
    }
}

extension VaultRecoveryiCloudVaultSelectionModuleInteractor: VaultRecoveryiCloudVaultSelectionModuleInteracting {
    func listVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void) {
        cloudRecoveryInteractor.listVaultsToRecover(completion: completion)
    }
}
