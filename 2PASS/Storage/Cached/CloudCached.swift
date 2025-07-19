// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct CloudDataItem {
    public let item: ItemEncryptedData
    public let metadata: Data
    
    public init(item: ItemEncryptedData, metadata: Data) {
        self.item = item
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
