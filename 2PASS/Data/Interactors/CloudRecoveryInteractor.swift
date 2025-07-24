// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol CloudRecoveryInteracting: AnyObject {
    func listVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void)
    func deleteVault(id: VaultID) async throws
}

final class CloudRecoveryInteractor {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension CloudRecoveryInteractor: CloudRecoveryInteracting {
    func listVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void) {
        mainRepository.cloudListVaultsToRecover(completion: completion)
    }
    
    func deleteVault(id: VaultID) async throws {
        try await mainRepository.cloudDeleteVault(id: id)
    }
}
