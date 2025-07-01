// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension MainRepositoryImpl {
    
    // MARK: Passwords
    
    func createEncryptedPassword(
        passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordEncryptedIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        vaultID: VaultID,
        uris: PasswordEncryptedURIs?,
        tagIds: [ItemTagID]?
    ) {
        encryptedStorage.createEncryptedPassword(
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
            vaultID: vaultID,
            uris: uris,
            tagIds: tagIds
        )
    }
    
    func updateEncryptedPassword(
        passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        modificationDate: Date,
        iconType: PasswordEncryptedIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        vaultID: VaultID,
        uris: PasswordEncryptedURIs?,
        tagIds: [ItemTagID]?
    ) {
        encryptedStorage.updateEncryptedPassword(
            passwordID: passwordID,
            name: name,
            username: username,
            password: password,
            notes: notes,
            modificationDate: modificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            vaultID: vaultID,
            uris: uris,
            tagIds: tagIds
        )
    }
    
    func encryptedPasswordsBatchUpdate(_ passwords: [PasswordEncryptedData]) {
        encryptedStorage.batchUpdateRencryptedPasswords(passwords, date: currentDate)
    }
    
    func getEncryptedPasswordEntity(passwordID: PasswordID) -> PasswordEncryptedData? {
        encryptedStorage.getEncryptedPasswordEntity(passwordID: passwordID)
    }
    
    func listEncryptedPasswords(in vaultID: VaultID) -> [PasswordEncryptedData] {
        encryptedStorage.listEncryptedPasswords(in: vaultID)
    }
    
    func listEncryptedPasswords(in vaultID: Common.VaultID, excludeProtectionLevels: Set<PasswordProtectionLevel>) -> [PasswordEncryptedData] {
        encryptedStorage.listEncryptedPasswords(in: vaultID, excludeProtectionLevels: excludeProtectionLevels)
    }
    
    func addEncryptedPassword(_ passwordID: PasswordID, to vaultID: VaultID) {
        encryptedStorage.addEncryptedPassword(passwordID, to: vaultID)
    }
    
    func deleteEncryptedPassword(passwordID: PasswordID) {
        encryptedStorage.deleteEncryptedPassword(passwordID: passwordID)
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
