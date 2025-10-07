// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CoreData

public final class InMemoryStorageDataSourceImpl {
    private let coreDataStack: CoreDataStack
    
    public var storageError: ((String) -> Void)?
    
    var context: NSManagedObjectContext {
        coreDataStack.context
    }
    
    public init() {
        self.coreDataStack = CoreDataStack(
            readOnly: false,
            name: "TwoPass",
            bundle: Bundle(for: InMemoryStorageDataSourceImpl.self),
            isPersistent: false
        )
        coreDataStack.logError = { Log($0, module: .storage) }
        coreDataStack.presentErrorToUser = { [weak self] in self?.storageError?($0) }
    }
    
    public func loadStore(completion: @escaping LoadStoreCallback) {
        coreDataStack.loadStore(completion: completion)
    }
}

extension InMemoryStorageDataSourceImpl: InMemoryStorageDataSource {
    
    public func createItem(
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
    ) {
        ItemMetadataEntity.createItem(
            on: context,
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

    public func updateMetadataItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int
    ) {
        ItemMetadataEntity.updateMetadata(
            on: context,
            for: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            contentType: contentType,
            contentVersion: contentVersion
        )
    }
    
    public func updateItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        ItemMetadataEntity.updateItem(
            on: context,
            for: itemID,
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
    
    public func batchUpdateRencryptedItems(_ items: [RawItemData], date: Date) {
        for item in items {
            if item.contentType == .login {
                if let loginEntity = LoginEntity.getLoginEntity(on: context, itemID: item.id, checkInTrash: true) {
                    do {
                        let decoder = JSONDecoder()
                        let loginContent = try decoder.decode(LoginItemContent.self, from: item.content)
                        
                        LoginEntity.updateLogin(
                            on: context,
                            entity: loginEntity,
                            modificationDate: date,
                            trashedStatus: item.trashedStatus,
                            protectionLevel: item.protectionLevel,
                            tagIds: item.tagIds,
                            name: item.name,
                            username: loginContent.username,
                            password: loginContent.password,
                            notes: loginContent.notes,
                            iconType: loginContent.iconType,
                            uris: loginContent.uris
                        )
                    } catch {
                        Log("Error decoding login content for batch update: \(error)", module: .storage)
                    }
                } else {
                    Log("Error while searching for Login Entity \(item.id)")
                }
            } else if item.contentType == .secureNote {
                if let secureNoteEntity = SecureNoteEntity.getSecureNoteEntity(on: context, itemID: item.id, checkInTrash: true) {
                    do {
                        let decoder = JSONDecoder()
                        let secureNoteContent = try decoder.decode(SecureNoteContent.self, from: item.content)
                        
                        SecureNoteEntity.updateSecureNote(
                            on: context,
                            entity: secureNoteEntity,
                            modificationDate: date,
                            trashedStatus: item.trashedStatus,
                            protectionLevel: item.protectionLevel,
                            tagIds: item.tagIds,
                            name: item.name,
                            text: secureNoteContent.text
                        )
                    } catch {
                        Log("Error decoding secure note content for batch update: \(error)", module: .storage)
                    }
                } else {
                    Log("Error while searching for SecureNote Entity \(item.id)")
                }
            } else {
                if let entity = RawEntity.getRawEntity(on: context, itemID: item.id, checkInTrash: true) {
                    RawEntity.updateRaw(
                        on: context,
                        entity: entity,
                        modificationDate: date,
                        trashedStatus: item.trashedStatus,
                        protectionLevel: item.protectionLevel,
                        tagIds: item.tagIds,
                        name: item.name,
                        contentType: item.contentType,
                        contentVersion: item.contentVersion,
                        content: item.content
                    )
                } else {
                    Log("Error while searching for Item Entity \(item.id)")
                }
            }
        }
    }
    
    public func getItemEntity(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> ItemData? {
        ItemMetadataEntity.getEntity(
            on: context,
            itemID: itemID,
            checkInTrash: checkInTrash
        )?.toData()
    }
    
    public func listItems(
        options: ItemsListOptions
    ) -> [ItemData] {
        ItemMetadataEntity.listItems(on: context, options: options)
            .map { $0.toData() }
    }

    public func deleteItem(itemID: ItemID) {
        guard let entity = ItemMetadataEntity.getEntity(
            on: context,
            itemID: itemID,
            checkInTrash: true
        ) else { return }
        ItemMetadataEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllItemEntities() {
        ItemMetadataEntity.deleteAllItemEntities(on: context)
    }
}

extension InMemoryStorageDataSourceImpl {
    public func createTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    ) {
        TagEntity
            .create(
                on: context,
                tagID: tagID,
                name: name,
                modificationDate: modificationDate,
                position: position,
                vaultID: vaultID,
                color: color
            )
    }
    
    public func updateTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    ) {
        TagEntity
            .update(
                on: context,
                tagID: tagID,
                name: name,
                modificationDate: modificationDate,
                position: position,
                vaultID: vaultID,
                color: color
            )
    }
    
    public func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date) {
        let listAll = TagEntity.listItems(on: context, options: .all)
        for tag in tags {
            if let entity = listAll.first(where: { $0.tagID == tag.id }) {
                TagEntity
                    .update(
                        on: context,
                        entity: entity,
                        name: tag.name,
                        modificationDate: date,
                        position: Int16(tag.position),
                        vaultID: tag.vaultID,
                        color: tag.color?.hexString
                    )
            } else {
                Log("Error while searching for Tag Entity \(tag.id)")
            }
        }
    }
    
    public func getTagEntity(
        tagID: ItemTagID
    ) -> ItemTagData? {
        TagEntity.getEntity(on: context, tagID: tagID)?
            .toData()
    }
    
    public func listTags(
        options: TagListOptions
    ) -> [ItemTagData] {
        TagEntity.listItems(on: context, options: options)
            .map { $0.toData() }
    }
    
    public func deleteTag(tagID: ItemTagID) {
        guard let entity = TagEntity.getEntity(on: context, tagID: tagID) else {
            return
        }
        TagEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllTagEntities() {
        TagEntity.deleteAllTagEntities(on: context)
    }
}

extension InMemoryStorageDataSourceImpl {
    public func createLoginItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) {
        LoginEntity.createLogin(
            on: context,
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            username: username,
            password: password,
            notes: notes,
            iconType: iconType,
            uris: uris
        )
    }
    
    public func updateLoginItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) {
        LoginEntity.updateLogin(
            on: context,
            for: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            username: username,
            password: password,
            notes: notes,
            iconType: iconType,
            uris: uris
        )
    }
    
    public func getLoginItem(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> LoginItemData? {
        LoginEntity.getLoginEntity(
            on: context,
            itemID: itemID,
            checkInTrash: checkInTrash
        )?.toData().asLoginItem
    }
    
    public func listLoginItems(
        options: ItemsListOptions
    ) -> [LoginItemData] {
        LoginEntity.listLoginEntities(on: context, options: options)
            .compactMap { $0.toData().asLoginItem }
    }
}

extension InMemoryStorageDataSourceImpl {
    public func createSecureNoteItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?
    ) {
        SecureNoteEntity.createSecureNote(
            on: context,
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            text: text
        )
    }
    
    public func updateSecureNoteItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?
    ) {
        SecureNoteEntity.updateSecureNote(
            on: context,
            for: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            text: text
        )
    }
    
    public func getSecureNoteItem(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> SecureNoteItemData? {
        SecureNoteEntity.getSecureNoteEntity(
            on: context,
            itemID: itemID,
            checkInTrash: checkInTrash
        )?.toData().asSecureNote
    }
    
    public func listSecureNoteItems(
        options: ItemsListOptions
    ) -> [SecureNoteItemData] {
        SecureNoteEntity.listSecureNoteEntities(on: context, options: options)
            .compactMap { $0.toData().asSecureNote }
    }
}

extension InMemoryStorageDataSourceImpl {
    public func listUsernames() -> [String] {
        LoginEntity.listLoginEntities(on: context, options: .allNotTrashed)
            .compactMap { $0.username }
    }
    
    public func warmUp() {
        // Artifically calling out context so it will prepare storage for concurrent access
        try? coreDataStack.context.save()
    }
    
    public func save() {
        coreDataStack.save()
    }
}
