// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct CloudDataPassword {
    public let password: ItemEncryptedData
    public let metadata: Data
    
    public init(password: ItemEncryptedData, metadata: Data) {
        self.password = password
        self.metadata = metadata
    }
}

public struct CloudDataDeletedItem {
    public let deletedItem: DeletedItemData
    public let metadata: Data
    
    public init(deletedItem: DeletedItemData, metadata: Data) {
        self.deletedItem = deletedItem
        self.metadata = metadata
    }
}

public struct CloudDataTagItem {
    public let tagItem: ItemTagEncryptedData
    public let metadata: Data
    
    public init(tagItem: ItemTagEncryptedData, metadata: Data) {
        self.tagItem = tagItem
        self.metadata = metadata
    }
}
