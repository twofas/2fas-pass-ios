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
        vaultID: VaultID,
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
            vaultID: vaultID,
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
        vaultID: VaultID,
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
            vaultID: vaultID,
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
            ItemMetadataEntity.updateItem(
                on: context,
                for: item.id,
                vaultID: item.vaultId,
                modificationDate: item.modificationDate,
                trashedStatus: item.trashedStatus,
                protectionLevel: item.protectionLevel,
                tagIds: item.tagIds,
                name: item.name,
                contentType: item.contentType,
                contentVersion: item.contentVersion,
                content: item.content
            )
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
        vaultID: VaultID,
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
            vaultID: vaultID,
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
        vaultID: VaultID,
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
            vaultID: vaultID,
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
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?,
        additionalInfo: String?
    ) {
        SecureNoteEntity.createSecureNote(
            on: context,
            itemID: itemID,
            vaultID: vaultID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            text: text,
            additionalInfo: additionalInfo
        )
    }

    public func updateSecureNoteItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?,
        additionalInfo: String?
    ) {
        SecureNoteEntity.updateSecureNote(
            on: context,
            for: itemID,
            vaultID: vaultID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            text: text,
            additionalInfo: additionalInfo
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
    public func createPaymentCardItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    ) {
        PaymentCardEntity.createPaymentCard(
            on: context,
            itemID: itemID,
            vaultID: vaultID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            cardHolder: cardHolder,
            cardNumber: cardNumber,
            expirationDate: expirationDate,
            securityCode: securityCode,
            notes: notes,
            cardNumberMask: cardNumberMask,
            cardIssuer: cardIssuer
        )
    }

    public func updatePaymentCardItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    ) {
        PaymentCardEntity.updatePaymentCard(
            on: context,
            for: itemID,
            vaultID: vaultID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            cardHolder: cardHolder,
            cardNumber: cardNumber,
            expirationDate: expirationDate,
            securityCode: securityCode,
            notes: notes,
            cardNumberMask: cardNumberMask,
            cardIssuer: cardIssuer
        )
    }

    public func getPaymentCardItem(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> PaymentCardItemData? {
        PaymentCardEntity.getPaymentCardEntity(
            on: context,
            itemID: itemID,
            checkInTrash: checkInTrash
        )?.toData().asPaymentCard
    }

    public func listPaymentCardItems(
        options: ItemsListOptions
    ) -> [PaymentCardItemData] {
        PaymentCardEntity.listPaymentCardEntities(on: context, options: options)
            .compactMap { $0.toData().asPaymentCard }
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
