// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol LocalStorage: AnyObject {
    func save()
    func listItems() -> [ItemEncryptedData]
    func listAllDeletedItems() -> [DeletedItemData]
    func listAllTags() -> [ItemTagData]
    func moveFromTrash(_ itemID: ItemID)
    func listTrashedItemsIDs() -> [ItemID]
    func createDeletedItem(_ deletedItem: DeletedItemData)
    func updateDeletedItem(_ deletedItem: DeletedItemData)
    func createItem(_ item: ItemEncryptedData)
    func updateItem(_ item: ItemEncryptedData)
    func createTag(_ tag: ItemTagData)
    func updateTag(_ tag: ItemTagData)
    func removeDeletedItem(_ deletedItemID: DeletedItemID)
    func removeTag(_ tagID: ItemTagID)
    func removeItem(_ itemID: ItemID)
    func currentVault() -> VaultEncryptedData?
}
