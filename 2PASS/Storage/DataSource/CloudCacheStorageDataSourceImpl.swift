// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CoreData

public final class CloudCacheStorageDataSourceImpl {
    private let coreDataStack: CoreDataStack
    
    public var storageError: ((String) -> Void)?
    
    var context: NSManagedObjectContext {
        coreDataStack.context
    }
    
    public init() {
        self.coreDataStack = CoreDataStack(
            readOnly: false,
            name: "CloudCache",
            bundle: Bundle(for: CloudCacheStorageDataSourceImpl.self),
            isPersistent: true
        )
        coreDataStack.logError = { Log($0, module: .storage) }
        coreDataStack.presentErrorToUser = { [weak self] in self?.storageError?($0) }
    }
}

extension CloudCacheStorageDataSourceImpl: CloudCacheStorageDataSource {
    // MARK: Encrypted Passwords
    
    public func createCloudCachedPassword(
        passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordEncryptedIconType,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        uris: PasswordEncryptedURIs?,
        metadata: Data
    ) {
        PasswordCachedEntity.create(
            on: context,
            passwordID: passwordID,
            name: name,
            username: username,
            password: password,
            notes: notes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            uris: uris,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func updateCloudCachedPassword(
        passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordEncryptedIconType,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        uris: PasswordEncryptedURIs?,
        metadata: Data
    ) {
        PasswordCachedEntity.update(
            on: context,
            for: passwordID,
            name: name,
            username: username,
            password: password,
            notes: notes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            uris: uris,
            metadata: metadata
        )
    }
    
    public func getCloudCachedPasswordEntity(passwordID: PasswordID) -> CloudDataPassword? {
        guard let entity = PasswordCachedEntity.getEntity(on: context, passwordID: passwordID) else {
            return nil
        }
        return .init(password: entity.toData(), metadata: entity.metadata)
    }
    
    public func listCloudCachedPasswords(in vaultID: VaultID) -> [CloudDataPassword] {
        PasswordCachedEntity.listItemsInVault(on: context, vaultID: vaultID)
            .map { .init(password: $0.toData(), metadata: $0.metadata) }
    }
    
    public func listAllCloudCachedPasswords() -> [CloudDataPassword] {
        PasswordCachedEntity.listItems(on: context)
            .map { .init(password: $0.toData(), metadata: $0.metadata) }
    }
    
    public func deleteCloudCachedPassword(passwordID: PasswordID) {
        guard let entity = PasswordCachedEntity.getEntity(on: context, passwordID: passwordID) else { return }
        PasswordCachedEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllCloudCachedPasswords() {
        let passwords = PasswordCachedEntity.listItems(on: context)
        passwords.forEach { entity in
            context.delete(entity)
        }
    }
    
    // MARK: Encrypted Vaults
    
    public func listCloudCachedVaults() -> [VaultCloudData] {
        VaultCachedEntity.listItems(on: context)
            .map { $0.toData() }
    }
    
    public func getCloudCachedVault(for vaultID: VaultID) -> VaultCloudData? {
        guard let vault = VaultCachedEntity.getEntity(on: context, vaultID: vaultID) else {
            return nil
        }
        return vault.toData()
    }
    
    public func createCloudCachedVault(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        VaultCachedEntity.create(
            on: context,
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec
        )
    }
    
    public func updateCloudCachedVault(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        VaultCachedEntity.update(
            on: context,
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec
        )
    }
    
    public func deleteCloudCachedVault(_ vaultID: VaultID) {
        guard let entity = VaultCachedEntity.getEntity(on: context, vaultID: vaultID) else { return }
        VaultCachedEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllCloudCachedVaults() {
        let vaults = VaultCachedEntity.listItems(on: context)
        vaults.forEach { entity in
            context.delete(entity)
        }
    }
    
    // MARK: Cloud Cached Tags
    
    public func createCloudCachedTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    ) {
        TagCachedEntity.create(
            on: context,
            tagID: tagID,
            name: name,
            color: color,
            position: position,
            modificationDate: modificationDate,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func updateCloudCachedTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    ) {
        TagCachedEntity.update(
            on: context,
            tagID: tagID,
            name: name,
            color: color,
            position: position,
            modificationDate: modificationDate,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func getCloudCachedTag(tagID: ItemTagID) -> CloudDataTagItem? {
        guard let entity = TagCachedEntity.getEntity(on: context, tagID: tagID) else {
            return nil
        }
        return .init(tagItem: entity.toData, metadata: entity.metadata)
    }
    
    public func listCloudCachedTags(in vaultID: VaultID, limit: Int?) -> [CloudDataTagItem] {
        TagCachedEntity.listItems(on: context, vaultID: vaultID, limit: limit)
            .map { .init(tagItem: $0.toData, metadata: $0.metadata) }
    }
    
    public func listAllCloudCachedTags(limit: Int?) -> [CloudDataTagItem] {
        TagCachedEntity.listItems(on: context, vaultID: nil, limit: limit)
            .map { .init(tagItem: $0.toData, metadata: $0.metadata) }
    }
    
    public func deleteCloudCachedTag(tagID: ItemTagID) {
        guard let entity = TagCachedEntity.getEntity(on: context, tagID: tagID) else {
            return
        }
        TagCachedEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllCloudCachedTags() {
        TagCachedEntity.listItems(on: context, vaultID: nil).forEach { entity in
            context.delete(entity)
        }
    }
    
    public func createCloudCachedDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    ) {
        DeletedItemCachedEntity.create(
            on: context,
            itemID: itemID,
            kind: kind,
            deletedAt: deletedAt,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func updateCloudCachedDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    ) {
        DeletedItemCachedEntity.update(
            on: context,
            itemID: itemID,
            kind: kind,
            deletedAt: deletedAt,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func listCloudCachedDeletedItems(in vaultID: VaultID, limit: Int?) -> [CloudDataDeletedItem] {
        DeletedItemCachedEntity.listItems(on: context, vaultID: vaultID, limit: limit)
            .map { .init(deletedItem: $0.toData, metadata: $0.metadata) }
    }
    
    public func listAllCloudCachedDeletedItems(limit: Int?) -> [CloudDataDeletedItem] {
        DeletedItemCachedEntity.listItems(on: context, vaultID: nil)
            .map { .init(deletedItem: $0.toData, metadata: $0.metadata) }
    }
    
    public func deleteCloudCachedDeletedItem(itemID: DeletedItemID) {
        guard let entity = DeletedItemCachedEntity.getEntity(on: context, itemID: itemID) else {
            return
        }
        DeletedItemCachedEntity.delete(on: context, entity: entity)
    }
    
    public func cloudCacheDeleteAllDeletedItems() {
        DeletedItemCachedEntity.listItems(on: context, vaultID: nil).forEach { entity in
            context.delete(entity)
        }
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
