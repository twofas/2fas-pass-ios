// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Backup
import Common

extension MainRepositoryImpl {
    func cloudListVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void) {
        cloudRecovery.listVaultsToRecover(completion: completion)
    }

    func cloudDeleteVault(id: VaultID) async throws {
        try await cloudRecovery.deleteVault(id: id)
    }
}
