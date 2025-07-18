// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol CloudCacheStorage: AnyObject {
    func purge()
    
    func deletePassword(passwordID: PasswordID)
    func deleteDeletedItem(deletedItemID: DeletedItemID)
    func deleteTag(tagID: ItemTagID)
    
    func save()
    
    func listPasswordIDs() -> [PasswordID]
    func listDeleteItemsIDs() -> [DeletedItemID]
    func listTagsItemsIDs() -> [ItemTagID]
    
    func listAllPasswords() -> [PasswordID: (password: ItemEncryptedData, metadata: Data)]
    func listAllDeletedItems() -> [CloudDataDeletedItem]
    func listAllTags() -> [CloudDataTagItem]
    
    func listAllPasswordsInCurrentVault() -> [(password: ItemEncryptedData, metadata: Data)]
    func listAllDeletedItemsInCurrentVault() -> [CloudDataDeletedItem]
    func listAllTagsInCurrentVault() -> [CloudDataTagItem]
    
    func createPassword(password: ItemEncryptedData, metadata: Data)
    func updatePassword(password: ItemEncryptedData, metadata: Data)
    
    func createDeletedItem(_ deletedItem: CloudDataDeletedItem)
    func updateDeletedItem(_ deletedItem: CloudDataDeletedItem)
    
    func createTagItem(_ tag: CloudDataTagItem)
    func updateTagItem(_ tag: CloudDataTagItem)
    
    func listPasswordIDsModificationDate() -> [(PasswordID, Date)]
    func listDeletedItemsIDsDeletitionDate() -> [(DeletedItemID, Date)]
    func listTagsItemsIDsModificationDate() -> [(DeletedItemID, Date)]
    
    var currentVault: VaultCloudData? { get }
    func listAllVaults() -> [VaultCloudData]
    func listAllVaultIDs() -> [VaultID]
    func createVault(vault: VaultCloudData)
    func updateVault(vault: VaultCloudData)
    func deleteVault(vaultID: VaultID)
}
