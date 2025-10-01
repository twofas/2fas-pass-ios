// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

public protocol EncryptedStorageDataSource: AnyObject {
    func loadStore(completion: @escaping Callback)
    var migrationRequired: Bool { get }
    
    var storageError: ((String) -> Void)? { get set }
    
    // MARK: Encrypted Items
    
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
    )
    
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
    )
    func batchUpdateRencryptedItems(_ items: [ItemEncryptedData], date: Date)
    
    func getEncryptedItemEntity(itemID: ItemID) -> ItemEncryptedData?
    
    func listEncryptedItems(in vaultID: VaultID) -> [ItemEncryptedData]
    func listEncryptedItems(in vaultID: VaultID, excludeProtectionLevels: Set<ItemProtectionLevel>) -> [ItemEncryptedData]
    
    func addEncryptedItem(_ itemID: ItemID, to vaultID: VaultID)
    
    func deleteEncryptedItem(itemID: ItemID)
    func deleteAllEncryptedItems(in vault: VaultID?)
    
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
    func deleteEncryptedTag(tagID: ItemTagID)
    func listEncryptedTags(in vaultID: VaultID) -> [ItemTagEncryptedData]
    func encryptedTagBatchUpdate(_ tags: [ItemTagEncryptedData], in vault: VaultID)
    func deleteAllEncryptedTags(in vault: VaultID)
    
    // MARK: Storage
    
    func warmUp()
    func save()
}
