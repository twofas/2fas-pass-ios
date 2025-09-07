// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Storage

extension MainRepositoryImpl {
    
    // MARK: Passwords
    
    func createItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: String,
        contentVersion: Int,
        content: Data
    ) {
        inMemoryStorage?.createItem(
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content
        )
    }
    
    func updateItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: String,
        contentVersion: Int,
        content: Data
    ) {
        inMemoryStorage?.updateItem(
            itemID: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content
        )
    }
    
    func updatePasswords(_ items: [RawItemData]) {
        items.forEach { item in
            inMemoryStorage?.updateItem(
                itemID: item.id,
                modificationDate: item.modificationDate,
                trashedStatus: item.trashedStatus,
                protectionLevel: item.protectionLevel,
                tagIds: item.tagIds,
                name: item.name,
                contentType: item.contentType.rawValue,
                contentVersion: item.contentVersion,
                content: item.content
            )
        }
    }
    
    func passwordsBatchUpdate(_ passwords: [RawItemData]) {
        inMemoryStorage?.batchUpdateRencryptedPasswords(passwords, date: currentDate)
    }
    
    func getPasswordEntity(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> RawItemData? {
        inMemoryStorage?.getPasswordEntity(itemID: itemID, checkInTrash: checkInTrash)
    }
    
    func listPasswords(
        options: PasswordListOptions
    ) -> [RawItemData] {
        inMemoryStorage?.listPasswords(options: options) ?? []
    }
    
    func listTrashedPasswords() -> [RawItemData] {
        inMemoryStorage?.listPasswords(options: .allTrashed) ?? []
    }
    
    func deletePassword(itemID: ItemID) {
        inMemoryStorage?.deletePassword(itemID: itemID)
    }
    
    func deleteAllPasswords() {
        inMemoryStorage?.deleteAllPasswordEntities()
    }
    
    // MARK: Tags
    
    func createTag(_ tag: ItemTagData) {
        inMemoryStorage?
            .createTag(
                tagID: tag.tagID,
                name: tag.name,
                modificationDate: tag.modificationDate,
                position: Int16(tag.position),
                vaultID: tag.vaultID,
                color: tag.color
            )
    }
    
    func updateTag(_ tag: ItemTagData) {
        inMemoryStorage?.updateTag(
            tagID: tag.tagID,
            name: tag.name,
            modificationDate: tag.modificationDate,
            position: Int16(tag.position),
            vaultID: tag.vaultID,
            color: tag.color)
    }
    
    func deleteTag(tagID: ItemTagID) {
        inMemoryStorage?.deleteTag(tagID: tagID)
    }
    
    func listTags(options: TagListOptions) -> [ItemTagData] {
        inMemoryStorage?.listTags(options: options) ?? []
    }
    
    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date) {
        inMemoryStorage?.batchUpdateRencryptedTags(tags, date: date)
    }
    
    // MARK: Other
    
    func saveStorage() {
        Log("Save In-memory Storage", module: .mainRepository)
        inMemoryStorage?.save()
    }
    
    func listUsernames() -> [String] {
        inMemoryStorage?.listUsernames() ?? []
    }
    
    func createInMemoryStorage() {
        inMemoryStorage = InMemoryStorageDataSourceImpl()
        inMemoryStorage?.warmUp()
        inMemoryStorage?.storageError = { [weak self] in self?.storageError?($0) }
    }
    
    func destroyInMemoryStorage() {
        inMemoryStorage = nil
    }
    
    var hasInMemoryStorage: Bool {
        inMemoryStorage != nil
    }
}
