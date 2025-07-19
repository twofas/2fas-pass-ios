// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol CloudCacheStorage: AnyObject {
    func purge()
    
    func deleteItem(itemID: ItemID)
    func deleteDeletedItem(deletedItemID: DeletedItemID)
    func deleteTag(tagID: ItemTagID)
    
    func save()
    
    func listItemIDs() -> [ItemID]
    func listDeleteItemsIDs() -> [DeletedItemID]
    func listTagsItemsIDs() -> [ItemTagID]
    
    func listAllItems() -> [ItemID: (item: ItemEncryptedData, metadata: Data)]
    func listAllDeletedItems() -> [CloudDataDeletedItem]
    func listAllTags() -> [CloudDataTagItem]
    
    func listAllItemsInCurrentVault() -> [(item: ItemEncryptedData, metadata: Data)]
    func listAllDeletedItemsInCurrentVault() -> [CloudDataDeletedItem]
    func listAllTagsInCurrentVault() -> [CloudDataTagItem]
    
    func createItem(item: ItemEncryptedData, metadata: Data)
    func updateItem(item: ItemEncryptedData, metadata: Data)
    
    func createDeletedItem(_ deletedItem: CloudDataDeletedItem)
    func updateDeletedItem(_ deletedItem: CloudDataDeletedItem)
    
    func createTagItem(_ tag: CloudDataTagItem)
    func updateTagItem(_ tag: CloudDataTagItem)
    
    func listItemIDsModificationDate() -> [(ItemID, Date)]
    func listDeletedItemsIDsDeletitionDate() -> [(DeletedItemID, Date)]
    func listTagsItemsIDsModificationDate() -> [(DeletedItemID, Date)]
    
    var currentVault: VaultCloudData? { get }
    func listAllVaults() -> [VaultCloudData]
    func listAllVaultIDs() -> [VaultID]
    func createVault(vault: VaultCloudData)
    func updateVault(vault: VaultCloudData)
    func deleteVault(vaultID: VaultID)
}
