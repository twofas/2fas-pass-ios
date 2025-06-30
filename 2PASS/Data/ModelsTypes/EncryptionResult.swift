// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct EncryptionResult {
    public let data: Data
    public let IV: Data
    public let salt: Data
    
    init(data: Data, IV: Data, salt: Data) {
        self.data = data
        self.IV = IV
        self.salt = salt
    }
}

public extension EncryptionResult {
    var base64String: String {
        let base64Cypher = data.base64EncodedString()
        let base64Salt = salt.base64EncodedString()
        let base64IV = IV.base64EncodedString()
        return "\(base64Cypher):\(base64Salt):\(base64IV)"
    }
    
    init?(_ str: String) {
        let array = str.split(separator: ":")
        guard array.count == 3,
              let data = Data(base64Encoded: String(array[0])),
              let salt = Data(base64Encoded: String(array[1])),
              let IV = Data(base64Encoded: String(array[2]))
        else { return nil }
        self.init(data: data, IV: IV, salt: salt)
    }
}
