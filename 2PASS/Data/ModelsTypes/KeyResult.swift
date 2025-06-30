// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct KeyResult {
    public let key: Data
    public let salt: Data
    
    init(key: Data, salt: Data) {
        self.key = key
        self.salt = salt
    }
}

public extension KeyResult {
    var base64String: String {
        let base64Key = key.base64EncodedString()
        let base64Salt = salt.base64EncodedString()
        return "\(base64Key):\(base64Salt)"
    }
    
    init?(_ str: String) {
        let array = str.split(separator: ":")
        guard array.count == 2,
              let key = Data(base64Encoded: String(array[0])),
              let salt = Data(base64Encoded: String(array[1]))
        else { return nil }
        self.init(key: key, salt: salt)
    }
}
