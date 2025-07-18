// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CoreData

public final class EncryptedStorageDataSourceImpl {
    private let coreDataStack: CoreDataStack
    
    public var storageError: ((String) -> Void)?
    
    var context: NSManagedObjectContext {
        coreDataStack.context
    }
    
    public init() {
        self.coreDataStack = CoreDataStack(
            readOnly: false,
            name: "ColdStorage",
            bundle: Bundle(for: EncryptedStorageDataSourceImpl.self),
            storeInGroup: true,
            migrator: CoreDataMigrator(momdSubdirectory: "ColdStorage", versions: [.init(rawValue: "ColdStorage"), .init(rawValue: "ColdStorage2")]),
            isPersistent: true
        )
        coreDataStack.logError = { Log($0, module: .storage) }
        coreDataStack.presentErrorToUser = { [weak self] in self?.storageError?($0) }
    }
}

extension EncryptedStorageDataSourceImpl: EncryptedStorageDataSource {
    
    public var migrationRequired: Bool {
        coreDataStack.migrationRequired
    }
    
    public func loadStore() {
        coreDataStack.loadStore()
    }
    
    // MARK: Encrypted Passwords
    
    public func createEncryptedPassword(
        itemID: PasswordID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        let entity = ItemEncryptedEntity.create(
            on: context,
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content,
            tagIds: tagIds
        )
        guard let vault = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID) else { return }
        vault.addToItems(entity)
    }
    
    public func updateEncryptedPassword(
        itemID: PasswordID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        let entity = ItemEncryptedEntity.update(
            on: context,
            for: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content,
            tagIds: tagIds
        )
        guard let vault = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID), let entity else { return }
        vault.addToItems(entity)
    }
    
    public func batchUpdateRencryptedPasswords(_ passwords: [ItemEncryptedData], date: Date) {
        guard let currentVaultID = passwords.first?.vaultID else {
            Log("Error while getting current vaultID for batch update")
            return
        }
        let listAll = ItemEncryptedEntity.listItems(on: context, vaultID: currentVaultID)
        for pass in passwords {
            if let entity = listAll.first(where: { $0.itemID == pass.itemID }) {
                ItemEncryptedEntity.update(
                    on: context,
                    entity: entity,
                    modificationDate: date,
                    trashedStatus: pass.trashedStatus,
                    protectionLevel: pass.protectionLevel,
                    contentType: pass.contentType,
                    contentVersion: pass.contentVersion,
                    content: pass.content,
                    tagIds: pass.tagIds
                )
            } else {
                Log("Error while searching for Password Encrypted Entity \(pass.itemID)")
            }
        }
    }
    
    public func getEncryptedPasswordEntity(itemID: PasswordID) -> ItemEncryptedData? {
        ItemEncryptedEntity.getEntity(on: context, itemID: itemID)?
            .toData()
    }

    public func listAllEncryptedItems() -> [ItemEncryptedData] {
        ItemEncryptedEntity.listItems(on: context, excludeProtectionLevels: [])
            .map({ $0.toData() })
    }
    
    public func listEncryptedItems(in vaultID: VaultID) -> [ItemEncryptedData] {
        listEncryptedItems(in: vaultID, excludeProtectionLevels: [])
    }
    
    public func listEncryptedItems(in vaultID: VaultID, excludeProtectionLevels: Set<ItemProtectionLevel>) -> [ItemEncryptedData] {
        guard let vault = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID) else { return [] }
        
        if excludeProtectionLevels.isEmpty {
            return VaultEncryptedEntity.listPasswords(on: context, vault: vault).map({ $0.toData() })
        } else {
            return ItemEncryptedEntity.listItems(on: context, excludeProtectionLevels: excludeProtectionLevels, vaultID: vaultID)
                .map({ $0.toData() })
        }
    }
    
    public func addEncryptedPassword(_ itemID: PasswordID, to vaultID: VaultID) {
        guard let entity = ItemEncryptedEntity.getEntity(on: context, itemID: itemID),
              let vault = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID)
        else { return }
        vault.addToItems(entity)
    }
    
    public func deleteEncryptedPassword(itemID: PasswordID) {
        guard let entity = ItemEncryptedEntity.getEntity(on: context, itemID: itemID) else { return }
        ItemEncryptedEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllEncryptedPasswords(in vaultID: VaultID?) {
        ItemEncryptedEntity.deleteAllEncryptedPasswords(on: context, vaultID: vaultID)
    }
    
    // MARK: Encrypted Vaults
    
    public func listEncrypteVaults() -> [VaultEncryptedData] {
        VaultEncryptedEntity.listItems(on: context)
            .map { $0.toData() }
    }
    
    public func getEncryptedVault(for vaultID: VaultID) -> VaultEncryptedData? {
        VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID)?
            .toData()
    }
    
    public func createEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        VaultEncryptedEntity.create(
            on: context,
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    public func updateEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        VaultEncryptedEntity.update(
            on: context,
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    public func deleteEncryptedVault(_ vaultID: VaultID) {
        guard let entity = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID) else { return }
        VaultEncryptedEntity.delete(on: context, entity: entity)
    }
    
    public func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        DeletedItemEncryptedEntity.create(
            on: context,
            itemID: id,
            kind: kind,
            deletedAt: deletedAt,
            vaultID: vaultID
        )
    }
    
    public func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        DeletedItemEncryptedEntity.update(
            on: context,
            itemID: id,
            kind: kind,
            deletedAt: deletedAt,
            vaultID: vaultID
        )
    }
    
    public func listDeletedItems(in vaultID: VaultID, limit: Int?) -> [DeletedItemData] {
        DeletedItemEncryptedEntity.listItems(on: context, vaultID: vaultID, limit: limit)
            .map({ $0.toData })
    }
    
    public func deleteDeletedItem(id: DeletedItemID) {
        guard let entity = DeletedItemEncryptedEntity.getEntity(on: context, itemID: id) else {
            return
        }
        DeletedItemEncryptedEntity.delete(on: context, entity: entity)
    }
    
    public func createEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        WebBrowserEncryptedEntity.create(from: data, on: context)
    }
    
    public func listEncryptedWebBrowsers() -> [WebBrowserEncryptedData] {
        WebBrowserEncryptedEntity.list(on: context)
            .map(WebBrowserEncryptedData.init)
    }
    
    public func updateEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        guard let entity = WebBrowserEncryptedEntity.find(id: data.id, on: context) else {
            Log("No entity available to update WebBrowserEncryptedEntity", module: .storage)
            return
        }
        entity.update(with: data)
    }
    
    public func deleteEncryptedWebBrowser(id: UUID) {
        guard let entity = WebBrowserEncryptedEntity.find(id: id, on: context) else {
            Log("No entity available to delete WebBrowserEncryptedEntity", module: .storage)
            return
        }
        context.delete(entity)
    }
    
    public func createEncryptedTag(_ tag: ItemTagEncryptedData) {
        TagEncryptedEntity.create(from: tag, on: context)
    }
    
    public func updateEncryptedTag(_ tag: ItemTagEncryptedData) {
        TagEncryptedEntity.update(from: tag, on: context)
    }
    
    public func deleteEncryptedTag(tagID: ItemTagID) {
        TagEncryptedEntity.delete(on: context, tagID: tagID)
    }
    
    public func listEncryptedTags(in vaultID: VaultID) -> [ItemTagEncryptedData] {
        TagEncryptedEntity.list(on: context, in: vaultID)
            .map(ItemTagEncryptedData.init)
    }
    
    public func encryptedTagBatchUpdate(_ tags: [ItemTagEncryptedData], in vaultID: VaultID) {
        let listAll: [ItemTagID: TagEncryptedEntity] = TagEncryptedEntity.list(on: context, in: vaultID)
            .reduce(into: [:]) { result, entity in
                result[entity.tagID] = entity
            }
        for tag in tags {
            if let entity = listAll[tag.tagID] {
                entity.update(from: tag)
            } else {
                Log("Error while searching for Tag Encrypted Entity \(tag.tagID)")
            }
        }
    }
    
    public func deleteAllEncryptedTags(in vault: VaultID) {
        let listAll = TagEncryptedEntity.list(on: context, in: vault)
        listAll.forEach { TagEncryptedEntity.delete(on: context, entity: $0) }
    }
    
    public func warmUp() {
        // Artifically calling out context so it will prepare storage for concurrent access
        coreDataStack.context.performAndWait { [weak self] in
            try? self?.coreDataStack.context.save()
        }
    }
    
    public func save() {
        coreDataStack.save()
    }
}
