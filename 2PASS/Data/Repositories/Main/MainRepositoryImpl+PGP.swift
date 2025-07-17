// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import ObjectivePGP

extension MainRepositoryImpl {
    
    func encryptUsingPGP(_ data: Data, key: Data) throws -> Data {
        let keys = try ObjectivePGP.readKeys(from: key)
        
        let encryptedData = try ObjectivePGP.encrypt(
            data,
            addSignature: false,
            using: keys
        )
        
        return encryptedData
    }
}
