// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Storage

public enum MigrationError: Error {
    case verificationFailed
}

extension MainRepositoryImpl {
    
    // MARK: Items
    
    func createEncryptedItem(
        itemID: ItemID,
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
        encryptedStorage.createEncryptedItem(
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content,
            vaultID: vaultID,
            tagIds: tagIds
        )
    }
    
    func updateEncryptedItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        encryptedStorage.updateEncryptedItem(
            itemID: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content,
            vaultID: vaultID,
            tagIds: tagIds
        )
    }
    
    func encryptedItemsBatchUpdate(_ items: [ItemEncryptedData]) {
        encryptedStorage.batchUpdateRencryptedItems(items, date: currentDate)
    }
    
    func getEncryptedItemEntity(itemID: ItemID) -> ItemEncryptedData? {
        encryptedStorage.getEncryptedItemEntity(itemID: itemID)
    }
    
    func listEncryptedItems(in vaultID: VaultID) -> [ItemEncryptedData] {
        encryptedStorage.listEncryptedItems(in: vaultID)
    }
    
    func listEncryptedItems(in vaultID: Common.VaultID, excludeProtectionLevels: Set<ItemProtectionLevel>) -> [ItemEncryptedData] {
        encryptedStorage.listEncryptedItems(in: vaultID, excludeProtectionLevels: excludeProtectionLevels)
    }
    
    func addEncryptedItem(_ itemID: ItemID, to vaultID: VaultID) {
        encryptedStorage.addEncryptedItem(itemID, to: vaultID)
    }
    
    func deleteEncryptedItem(itemID: ItemID) {
        encryptedStorage.deleteEncryptedItem(itemID: itemID)
    }
    
    func deleteAllEncryptedItems() {
        encryptedStorage.deleteAllEncryptedItems(in: selectedVault?.vaultID)
    }
    
    // MARK: Encrypted Vaults
    
    func listEncrypteVaults() -> [VaultEncryptedData] {
        encryptedStorage.listEncrypteVaults()
    }
    
    func getEncryptedVault(for vaultID: VaultID) -> VaultEncryptedData? {
        encryptedStorage.getEncryptedVault(for: vaultID)
    }
    
    func createEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        encryptedStorage.createEncryptedVault(
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    func updateEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        encryptedStorage.updateEncryptedVault(
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    func deleteAllVaults() {
        listEncrypteVaults().forEach { vault in
            deleteEncryptedVault(vault.vaultID)
        }
        saveEncryptedStorage()
    }
    
    func deleteEncryptedVault(_ vaultID: VaultID) {
        encryptedStorage.deleteEncryptedVault(vaultID)
    }
    
    func saveEncryptedStorage() {
        Log("Save Encrypted Storage", module: .mainRepository)
        encryptedStorage.save()
    }
    
    var selectedVault: VaultEncryptedData? {
        _selectedVault
    }
    
    func selectVault(_ vaultID: VaultID) {
        _selectedVault = encryptedStorage.getEncryptedVault(for: vaultID)
    }
    
    func clearVault() {
        _selectedVault = nil
    }
    
    func requiresReencryptionMigration() -> Bool {
        hasEncryptionReference && encryptedStorage.migrationRequired
    }
    
    func loadEncryptedStore() {
        encryptedStorage.loadStore()
        encryptedStorage.warmUp()
    }
    
    func loadEncryptedStoreWithReencryptionMigration() {
        MigrationController.current = .init(
            setupKeys: { vaultID in
                guard self.hasCachedKeys() == false else {
                    return
                }
                
                guard let masterKey = self.empheralMasterKey else {
                    Log("Error while getting Master Key - it's missing", severity: .error)
                    return
                }
                
                guard let trustedKey = self.generateTrustedKeyForVaultID(vaultID, using: masterKey.hexEncodedString()),
                    let trustedKeyData = Data(hexString: trustedKey) else {
                    return
                }
                self.setTrustedKey(trustedKeyData)
                
                guard let secureKey = self.generateSecureKeyForVaultID(vaultID, using: masterKey.hexEncodedString()),
                    let secureKeyData = Data(hexString: secureKey) else {
                    return
                }
                self.setSecureKey(secureKeyData)
                
                guard let externalKey = self.generateExternalKeyForVaultID(vaultID, using: masterKey.hexEncodedString()),
                    let externalKeyData = Data(hexString: externalKey) else {
                    return
                }
                self.setExternalKey(externalKeyData)
                
                self.preparedCachedKeys()
            },
            encrypt: { data, protectionLevel in
                if let key = self.getKey(isPassword: false, protectionLevel: protectionLevel) {
                    return self.encrypt(data, key: key)
                }
                return nil
            },
            decrypt: { data, protectionLevel in
                if let key = self.getKey(isPassword: false, protectionLevel: protectionLevel) {
                    return self.decrypt(data, key: key)
                }
                return nil
            }
        )
        
        encryptedStorage.loadStore()
        
        MigrationController.current = nil
    }
    
    // MARK: Deleted Items
    
    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        Log("Creating Deleted Item for ItemID: \(id)", module: .mainRepository)
        encryptedStorage.createDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }
    
    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        Log("Updating Deleted Item for ItemID: \(id)", module: .mainRepository)
        encryptedStorage.updateDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }
    
    func listDeletedItems(in vaultID: VaultID, limit: Int?) -> [DeletedItemData] {
        encryptedStorage.listDeletedItems(in: vaultID, limit: limit)
    }
    
    func deleteDeletedItem(id: DeletedItemID) {
        Log("Deleting Deleted Item for ItemID: \(id)", module: .mainRepository)
        encryptedStorage.deleteDeletedItem(id: id)
    }
    
    // MARK: Tags
    
    func createEncryptedTag(_ tag: ItemTagEncryptedData) {
        encryptedStorage.createEncryptedTag(tag)
    }
    
    func updateEncryptedTag(_ tag: ItemTagEncryptedData) {
        encryptedStorage.updateEncryptedTag(tag)
    }
    
    func deleteEncryptedTag(tagID: ItemTagID) {
        encryptedStorage.deleteEncryptedTag(tagID: tagID)
    }
    
    func listEncryptedTags(in vaultID: VaultID) -> [ItemTagEncryptedData] {
        encryptedStorage.listEncryptedTags(in: vaultID)
    }
    
    func encryptedTagBatchUpdate(_ tags: [ItemTagEncryptedData], in vault: VaultID) {
        encryptedStorage.encryptedTagBatchUpdate(tags, in: vault)
    }
    
    func deleteAllEncryptedTags(in vault: VaultID) {
        encryptedStorage.deleteAllEncryptedTags(in: vault)
    }
    
    // MARK: Web Browser Extension
    
    func createEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        encryptedStorage.createEncryptedWebBrowser(data)
    }
    
    func updateEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        encryptedStorage.updateEncryptedWebBrowser(data)
    }
    
    func deleteEncryptedWebBrowser(id: UUID) {
        encryptedStorage.deleteEncryptedWebBrowser(id: id)
    }
    
    func listEncryptedWebBrowsers() -> [WebBrowserEncryptedData] {
        encryptedStorage.listEncryptedWebBrowsers()
    }
}
