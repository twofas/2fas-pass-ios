// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

final class LocalStorageImpl {
    private let passwordInteractor: PasswordInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let tagInteractor: TagInteracting
    private let mainRepository: MainRepository
    
    init(
        passwordInteractor: PasswordInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        tagInteractor: TagInteracting,
        mainRepository: MainRepository
    ) {
        self.passwordInteractor = passwordInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.tagInteractor = tagInteractor
        self.mainRepository = mainRepository
    }
}

extension LocalStorageImpl: LocalStorage {
    func save() {
        passwordInteractor.saveStorage()
    }
    
    func listItems() -> [ItemEncryptedData] {
        passwordInteractor.listEncryptedItems()
    }
    
    func listAllDeletedItems() -> [DeletedItemData] {
        deletedItemsInteractor.listDeletedItems()
    }
    
    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
    }
    
    func listTrashedItemsIDs() -> [ItemID] {
        passwordInteractor.listTrashedItems().map({ $0.id })
    }
    
    func createDeletedItem(_ deletedItem: DeletedItemData) {
        deletedItemsInteractor.createDeletedItem(
            id: deletedItem.itemID,
            kind: deletedItem.kind,
            deletedAt: deletedItem.deletedAt
        )
    }
    
    func moveFromTrash(_ itemID: ItemID) {
        passwordInteractor.markAsNotTrashed(for: itemID)
    }
    
    func updateDeletedItem(_ deletedItem: DeletedItemData) {
        deletedItemsInteractor.updateDeletedItem(
            id: deletedItem.itemID,
            kind: deletedItem.kind,
            deletedAt: deletedItem.deletedAt
        )
    }
    
    func createItem(_ item: ItemEncryptedData) {
        passwordInteractor.createEncryptedItem(item)
    }
    
    func updateItem(_ item: ItemEncryptedData) {
        passwordInteractor.updateEncryptedItem(item)
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
        passwordInteractor.markAsTrashed(for: itemID)
    }
    
    func currentVault() -> VaultEncryptedData? {
        mainRepository.selectedVault
    }
}
