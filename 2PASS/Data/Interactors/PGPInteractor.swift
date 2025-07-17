// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import ObjectivePGP

public protocol PGPInteracting {
    func encryptUsingSupportKey(_ data: Data) throws -> Data
}

class PGPInteractor: PGPInteracting {
    
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    func encryptUsingSupportKey(_ data: Data) throws -> Data {
        let publicKeyPath = Bundle.main.url(forResource: "security_public", withExtension: "asc")!
        let publicKeyData = try Data(contentsOf: publicKeyPath)
        return try mainRepository.encryptUsingPGP(data, key: publicKeyData)
    }
}
