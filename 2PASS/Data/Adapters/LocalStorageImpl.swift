// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

final class LocalStorageImpl {
    private let itemsInteractor: ItemsInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let tagInteractor: TagInteracting
    private let mainRepository: MainRepository
    
    init(
        itemsInteractor: ItemsInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        tagInteractor: TagInteracting,
        mainRepository: MainRepository
    ) {
        self.itemsInteractor = itemsInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.tagInteractor = tagInteractor
        self.mainRepository = mainRepository
    }
}

extension LocalStorageImpl: LocalStorage {
    func save() {
        itemsInteractor.saveStorage()
    }
    
    func listItems() -> [ItemEncryptedData] {
        itemsInteractor.listEncryptedItems()
    }
    
    func listAllDeletedItems() -> [DeletedItemData] {
        deletedItemsInteractor.listDeletedItems()
    }
    
    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
    }
    
    func listTrashedItemsIDs() -> [ItemID] {
        itemsInteractor.listTrashedItems().map({ $0.id })
    }
    
    func createDeletedItem(_ deletedItem: DeletedItemData) {
        deletedItemsInteractor.createDeletedItem(
            id: deletedItem.itemID,
            kind: deletedItem.kind,
            deletedAt: deletedItem.deletedAt
        )
    }
    
    func moveFromTrash(_ itemID: ItemID) {
        itemsInteractor.markAsNotTrashed(for: itemID)
    }
    
    func updateDeletedItem(_ deletedItem: DeletedItemData) {
        deletedItemsInteractor.updateDeletedItem(
            id: deletedItem.itemID,
            kind: deletedItem.kind,
            deletedAt: deletedItem.deletedAt
        )
    }
    
    func createItem(_ item: ItemEncryptedData) {
        itemsInteractor.createEncryptedItem(item)
    }
    
    func updateItem(_ item: ItemEncryptedData) {
        itemsInteractor.updateEncryptedItem(item)
    }
    
    func removeDeletedItem(_ deletedItem: DeletedItemID) {
        deletedItemsInteractor.deleteDeletedItem(id: deletedItem)
    }
    
    func createTag(_ tag: ItemTagData) {
        tagInteractor.createTag(data: tag)
    }
    
    func updateTag(_ tag: ItemTagData) {
        tagInteractor.updateTag(data: tag)
    }
    
    func removeTag(_ tagID: ItemTagID) {
        tagInteractor.deleteTag(tagID: tagID)
    }
    
    func removeItem(_ itemID: ItemID) {
        itemsInteractor.markAsTrashed(for: itemID)
    }
    
    func currentVault() -> VaultEncryptedData? {
        mainRepository.selectedVault
    }
}
