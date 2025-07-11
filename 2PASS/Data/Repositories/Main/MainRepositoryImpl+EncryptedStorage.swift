// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum MigrationError: Error {
    case verificationFailed
}

extension MainRepositoryImpl {
    
    // MARK: Passwords
    
    func createEncryptedPassword(
        passwordID: PasswordID,
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
        encryptedStorage.createEncryptedPassword(
            itemID: passwordID,
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
    
    func updateEncryptedPassword(
        passwordID: PasswordID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        encryptedStorage.updateEncryptedPassword(
            itemID: passwordID,
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
    
    func encryptedPasswordsBatchUpdate(_ passwords: [ItemEncryptedData]) {
        encryptedStorage.batchUpdateRencryptedPasswords(passwords, date: currentDate)
    }
    
    func getEncryptedPasswordEntity(passwordID: PasswordID) -> ItemEncryptedData? {
        encryptedStorage.getEncryptedPasswordEntity(itemID: passwordID)
    }
    
    func listEncryptedPasswords(in vaultID: VaultID) -> [ItemEncryptedData] {
        encryptedStorage.listEncryptedItems(in: vaultID)
    }
    
    func listEncryptedPasswords(in vaultID: Common.VaultID, excludeProtectionLevels: Set<ItemProtectionLevel>) -> [ItemEncryptedData] {
        encryptedStorage.listEncryptedItems(in: vaultID, excludeProtectionLevels: excludeProtectionLevels)
    }
    
    func addEncryptedPassword(_ passwordID: PasswordID, to vaultID: VaultID) {
        encryptedStorage.addEncryptedPassword(passwordID, to: vaultID)
    }
    
    func deleteEncryptedPassword(passwordID: PasswordID) {
        encryptedStorage.deleteEncryptedPassword(itemID: passwordID)
    }
    
    func deleteAllEncryptedPasswords() {
        encryptedStorage.deleteAllEncryptedPasswords(in: selectedVault?.vaultID)
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
    
    func shouldMigrate() -> Bool {
        encryptedStorage.encryptedPasswordsCount() > 0
    }
    
    func migrateDatabaseFromPasswordsToItems() throws(MigrationError) {
        let allPasswords = encryptedStorage.listEncryptedPasswords()
        guard allPasswords.isEmpty == false else {
            return
        }
        
        let allItemsIds: Set<PasswordID> = encryptedStorage.listAllEncryptedItems().reduce(into: []) { output, item in
            output.insert(item.itemID)
        }
        
        for password in allPasswords {
            guard let key = getKey(isPassword: false, protectionLevel: password.protectionLevel) else {
                continue
            }
                        
            let name = {
                if let name = password.name, let nameData = decrypt(name, key: key) {
                    return String(data: nameData, encoding: .utf8)
                }
                return nil
            }()
            
            let username = {
                if let username = password.username, let usernameData = decrypt(username, key: key) {
                    return String(data: usernameData, encoding: .utf8)
                }
                return nil
            }()
            
            let notes = {
                if let notes = password.notes, let notesData = decrypt(notes, key: key) {
                    return String(data: notesData, encoding: .utf8)
                }
                return nil
            }()
            
            let uris: [PasswordURI]? = {
                guard let passEncryptedUris = password.uris else {
                    return nil
                }
                
                let urisData = passEncryptedUris.uris
                let matchList = passEncryptedUris.match
                
                guard let decryptedUrisData = decrypt(urisData, key: key) else {
                    return nil
                }
                
                guard let uris = try? jsonDecoder.decode([String].self, from: decryptedUrisData) else {
                    return nil
                }
                
                guard uris.count == matchList.count else {
                    return nil
                }
                
                return uris.enumerated().compactMap { index, uri in
                    guard let match = matchList[safe: index] else {
                        return nil
                    }
                    return PasswordURI(uri: uri, match: match)
                }
            }()
            
            let content = PasswordItemContent(
                name: name,
                username: username,
                password: password.password,
                notes: notes,
                iconType: .default,
                uris: uris
            )
            
            guard let contentData = try? jsonEncoder.encode(content), let contentDataEnc = encrypt(contentData, key: key) else {
                continue
            }
            
            if allItemsIds.contains(password.passwordID) {
                encryptedStorage.updateEncryptedPassword(
                    itemID: password.passwordID,
                    modificationDate: password.modificationDate,
                    trashedStatus: password.trashedStatus,
                    protectionLevel: password.protectionLevel,
                    contentType: .login,
                    contentVersion: 1,
                    content: contentDataEnc,
                    vaultID: password.vaultID,
                    tagIds: password.tagIds
                )
            } else {
                encryptedStorage.createEncryptedPassword(
                    itemID: password.passwordID,
                    creationDate: password.creationDate,
                    modificationDate: password.modificationDate,
                    trashedStatus: password.trashedStatus,
                    protectionLevel: password.protectionLevel,
                    contentType: .login,
                    contentVersion: 1,
                    content: contentDataEnc,
                    vaultID: password.vaultID,
                    tagIds: password.tagIds
                )
            }
        }
        
        encryptedStorage.save()
        
        guard verifyMigration(oldPasswords: allPasswords) else {
            throw MigrationError.verificationFailed
        }
        
        encryptedStorage.deleteAllEncryptedPasswords()
        encryptedStorage.save()
    }
    
    private func verifyMigration(oldPasswords: [PasswordEncryptedData]) -> Bool {
        let allPasswordIds: Set<PasswordID> = oldPasswords.reduce(into: []) { output, password in
            output.insert(password.passwordID)
        }
        let allItemsIds: Set<PasswordID> = encryptedStorage.listAllEncryptedItems().reduce(into: []) { output, item in
            output.insert(item.itemID)
        }
        return allItemsIds.isSuperset(of: allPasswordIds)
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
