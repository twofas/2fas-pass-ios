// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Backup
import Common

final class CloudCacheStorageImpl {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension CloudCacheStorageImpl: CloudCacheStorage {
    var currentVault: VaultCloudData? {
        guard let currentVaultID = mainRepository.selectedVault?.vaultID else {
            Log("CloudCacheStorageImpl: can't get vaultID while getting current Vault", module: .interactor, severity: .error)
            return nil
        }
        return mainRepository.cloudCacheListVaults().first(where: { $0.id == currentVaultID })
    }
    
    func purge() {
        mainRepository.cloudCacheDeleteAllVaults()
        mainRepository.cloudCacheDeleteAllPasswords()
        mainRepository.cloudCacheDeleteAllDeletedItems()
        mainRepository.cloudCacheDeleteAllTags()
    }
    
    func deletePassword(passwordID: PasswordID) {
        mainRepository.cloudCacheDeletePassword(passwordID: passwordID)
    }
    
    func deleteDeletedItem(deletedItemID: DeletedItemID) {
        mainRepository.cloudCacheDeleteDeletedItem(itemID: deletedItemID)
    }
    
    func deleteTag(tagID: ItemTagID) {
        mainRepository.cloudCacheDeleteTag(tagID: tagID)
    }
    
    func save() {
        Log("CloudCacheStorageImpl: saving Cloud Cache", module: .interactor)
        mainRepository.cloudCacheSave()
    }
    
    func listPasswordIDs() -> [PasswordID] {
        let list = mainRepository.cloudCacheListAllPasswords()
        return list.map { pass in
            pass.password.passwordID
        }
    }
    
    func listPasswordIDsModificationDate() -> [(PasswordID, Date)] {
        let list = mainRepository.cloudCacheListAllPasswords()
        return list.map { pass in
            (pass.password.passwordID, pass.password.modificationDate)
        }
    }
    
    func listDeleteItemsIDs() -> [DeletedItemID] {
        let list = mainRepository.cloudCacheListAllDeletedItems(limit: nil)
        return list.map { deletedItems in
            deletedItems.deletedItem.itemID
        }
    }

    func listDeletedItemsIDsDeletitionDate() -> [(DeletedItemID, Date)] {
        let list = mainRepository.cloudCacheListAllDeletedItems(limit: nil)
        return list.map { deletedItems in
            (deletedItems.deletedItem.itemID, deletedItems.deletedItem.deletedAt)
        }
    }
    
    func listTagsItemsIDs() -> [ItemTagID] {
        let list = mainRepository.cloudCacheListAllTags(limit: nil)
        return list.map { tag in
            tag.tagItem.id
        }
    }
    
    func listTagsItemsIDsModificationDate() -> [(DeletedItemID, Date)] {
        let list = mainRepository.cloudCacheListAllTags(limit: nil)
        return list.map { tag in
            (tag.tagItem.id, tag.tagItem.modificationDate)
        }
    }

    func listAllPasswordsInCurrentVault() -> [(password: PasswordEncryptedData, metadata: Data)] {
        guard let currentVaultID = currentVault?.vaultID else {
            Log("CloudCacheStorageImpl: can't get vaultID while listing all Passwords", module: .interactor, severity: .error)
            return []
        }
        let list = mainRepository.cloudCacheListPasswords(in: currentVaultID)
        return list.map {
            (password: $0.password, metadata: $0.metadata)
        }
    }
    
    func listAllPasswords() -> [PasswordID: (password: PasswordEncryptedData, metadata: Data)] {
        var result: [PasswordID: (password: PasswordEncryptedData, metadata: Data)] = [:]
        let list = mainRepository.cloudCacheListAllPasswords()
        for pass in list {
            result[pass.password.passwordID] = (password: pass.password, metadata: pass.metadata)
        }
        return result
    }
    
    func listAllDeletedItems() -> [CloudDataDeletedItem] {
        mainRepository.cloudCacheListAllDeletedItems(limit: nil)
    }
    
    func listAllDeletedItemsInCurrentVault() -> [CloudDataDeletedItem] {
        guard let currentVaultID = currentVault?.vaultID else {
            Log("CloudCacheStorageImpl: can't get vaultID while listing all Deleted Items", module: .interactor, severity: .error)
            return []
        }
        return mainRepository.cloudCacheListDeletedItems(in: currentVaultID, limit: nil)
    }
    
    func listAllTags() -> [CloudDataTagItem] {
        mainRepository.cloudCacheListAllTags(limit: nil)
    }
    
    func listAllTagsInCurrentVault() -> [CloudDataTagItem] {
        guard let currentVaultID = currentVault?.vaultID else {
            Log("CloudCacheStorageImpl: can't get vaultID while listing all Tags", module: .interactor, severity: .error)
            return []
        }
        return mainRepository.cloudCacheListTags(in: currentVaultID, limit: nil)
    }
    
    func createPassword(password: PasswordEncryptedData, metadata: Data) {
        Log("CloudCacheStorageImpl: creating Password", module: .interactor, save: false)
        mainRepository.cloudCacheCreatePassword(
            passwordID: password.passwordID,
            name: password.name,
            username: password.username,
            password: password.password,
            notes: password.notes,
            creationDate: password.creationDate,
            modificationDate: password.modificationDate,
            iconType: password.iconType,
            trashedStatus: password.trashedStatus,
            protectionLevel: password.protectionLevel,
            vaultID: password.vaultID,
            uris: password.uris,
            metadata: metadata
        )
    }
    
    func updatePassword(password: PasswordEncryptedData, metadata: Data) {
        Log("CloudCacheStorageImpl: updating Password", module: .interactor, save: false)
        mainRepository.cloudCacheUpdatePassword(
            passwordID: password.passwordID,
            name: password.name,
            username: password.username,
            password: password.password,
            notes: password.notes,
            creationDate: password.creationDate,
            modificationDate: password.modificationDate,
            iconType: password.iconType,
            trashedStatus: password.trashedStatus,
            protectionLevel: password.protectionLevel,
            uris: password.uris,
            metadata: metadata
        )
    }
    
    func createDeletedItem(_ deletedItem: CloudDataDeletedItem) {
        Log("CloudCacheStorageImpl: creating Deleted Item", module: .interactor, save: false)
        mainRepository
            .cloudCacheCreateDeletedItem(
                metadata: deletedItem.metadata,
                itemID: deletedItem.deletedItem.itemID,
                kind: deletedItem.deletedItem.kind,
                deletedAt: deletedItem.deletedItem.deletedAt,
                in: deletedItem.deletedItem.vaultID
            )
    }
    
    func updateDeletedItem(_ deletedItem: CloudDataDeletedItem) {
        Log("CloudCacheStorageImpl: updating Deleted Item", module: .interactor, save: false)
        mainRepository
            .cloudCacheUpdateDeletedItem(
                metadata: deletedItem.metadata,
                itemID: deletedItem.deletedItem.itemID,
                kind: deletedItem.deletedItem.kind,
                deletedAt: deletedItem.deletedItem.deletedAt,
                in: deletedItem.deletedItem.vaultID
            )
    }
    
    func createTagItem(_ tag: CloudDataTagItem) {
        Log("CloudCacheStorageImpl: creating Tag Item", module: .interactor, save: false)
        mainRepository
            .cloudCacheCreateTag(
                metadata: tag.metadata,
                tagID: tag.tagItem.tagID,
                name: tag.tagItem.name,
                color: tag.tagItem.color,
                position: Int16(tag.tagItem.position),
                modificationDate: tag.tagItem.modificationDate,
                vaultID: tag.tagItem.vaultID
            )
    }
    
    func updateTagItem(_ tag: CloudDataTagItem) {
        Log("CloudCacheStorageImpl: updating Tag Item", module: .interactor, save: false)
        mainRepository
            .cloudCacheUpdateTag(
                metadata: tag.metadata,
                tagID: tag.tagItem.tagID,
                name: tag.tagItem.name,
                color: tag.tagItem.color,
                position: Int16(tag.tagItem.position),
                modificationDate: tag.tagItem.modificationDate,
                vaultID: tag.tagItem.vaultID
            )
    }
    
    func listAllVaults() -> [VaultCloudData] {
        mainRepository.cloudCacheListVaults()
    }
    
    func listAllVaultIDs() -> [VaultID] {
        mainRepository.cloudCacheListVaults().map({ $0.vaultID })
    }
    
    func createVault(vault: VaultCloudData) {
        Log("CloudCacheStorageImpl: creating Vault", module: .interactor, save: false)
        mainRepository.cloudCacheCreateVault(
            vaultID: vault.vaultID,
            name: vault.name,
            createdAt: vault.createdAt,
            updatedAt: vault.updatedAt,
            metadata: vault.metadata,
            deviceNames: vault.deviceNames,
            deviceID: vault.deviceID,
            schemaVersion: vault.schemaVersion,
            seedHash: vault.seedHash,
            reference: vault.reference,
            kdfSpec: vault.kdfSpec
        )
    }
    
    func updateVault(vault: VaultCloudData) {
        Log("CloudCacheStorageImpl: updating Vault", module: .interactor, save: false)
        mainRepository.cloudCacheUpdateVault(
            vaultID: vault.vaultID,
            name: vault.name,
            createdAt: vault.createdAt,
            updatedAt: vault.updatedAt,
            metadata: vault.metadata,
            deviceNames: vault.deviceNames,
            deviceID: vault.deviceID,
            schemaVersion: vault.schemaVersion,
            seedHash: vault.seedHash,
            reference: vault.reference,
            kdfSpec: vault.kdfSpec
        )
    }
    
    func deleteVault(vaultID: VaultID) {
        mainRepository.cloudCacheDeleteVault(vaultID)
    }
}
