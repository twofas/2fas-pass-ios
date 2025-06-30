// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

public protocol EncryptedStorageDataSource: AnyObject {
    var storageError: ((String) -> Void)? { get set }
    
    // MARK: Encrypted Passwords
    
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
    )
    
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
    )
    func batchUpdateRencryptedPasswords(_ passwords: [PasswordEncryptedData], date: Date)
    
    func getEncryptedPasswordEntity(passwordID: PasswordID) -> PasswordEncryptedData?
    
    func listEncryptedPasswords(in vaultID: VaultID) -> [PasswordEncryptedData]
    func listEncryptedPasswords(in vaultID: VaultID, excludeProtectionLevels: Set<PasswordProtectionLevel>) -> [PasswordEncryptedData]
    
    func addEncryptedPassword(_ passwordID: PasswordID, to vaultID: VaultID)
    
    func deleteEncryptedPassword(passwordID: PasswordID)
    func deleteAllEncryptedPasswords(in vault: VaultID?)
    
    // MARK: Encrypted Vaults
    
    func listEncrypteVaults() -> [VaultEncryptedData]
    func getEncryptedVault(for vaultID: VaultID) -> VaultEncryptedData?
    func createEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    )
    func updateEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    )
    func deleteEncryptedVault(_ vaultID: VaultID)
    
    // MARK: Deleted Items
    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID)
    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID)
    func listDeletedItems(in vaultID: VaultID, limit: Int?) -> [DeletedItemData]
    func deleteDeletedItem(id: DeletedItemID)
    
    // MARK: Web Browsers
    func createEncryptedWebBrowser(_ data: WebBrowserEncryptedData)
    func updateEncryptedWebBrowser(_ data: WebBrowserEncryptedData)
    func deleteEncryptedWebBrowser(id: UUID)
    func listEncryptedWebBrowsers() -> [WebBrowserEncryptedData]
    
    // MARK: Tags
    func createEncryptedTag(_ tag: ItemTagEncryptedData)
    func updateEncryptedTag(_ tag: ItemTagEncryptedData)
    func deleteEncryptedTag(id: ItemTagID) -> Bool
    func listEncryptedTags(in vaultID: VaultID) -> [ItemTagEncryptedData]
    
    // MARK: Storage
    
    func warmUp()
    func save()
}
