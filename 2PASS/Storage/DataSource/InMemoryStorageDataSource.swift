// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

public protocol InMemoryStorageDataSource: AnyObject {
    var storageError: ((String) -> Void)? { get set }
    func loadStore(completion: @escaping Callback)
    
    // MARK: - Items
    
    func createItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    )
    
    func updateItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    )
    
    func batchUpdateRencryptedItems(_ items: [RawItemData], date: Date)
    
    func getItemEntity(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> RawItemData?
    
    func listItems(
        options: ItemsListOptions
    ) -> [RawItemData]
    
    func deleteItem(itemID: ItemID)
    func deleteAllItemEntities()
    
    // MARK: - Tags
    
    func createTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    )
    
    func updateTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    )
    
    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date)
    
    func getTagEntity(
        tagID: ItemTagID
    ) -> ItemTagData?
    
    func listTags(
        options: TagListOptions
    ) -> [ItemTagData]
    
    func deleteTag(tagID: ItemTagID)
    func deleteAllTagEntities()
    
    // MARK: - Other
    
    func listUsernames() -> [String]
    func warmUp()
    func save()
}
