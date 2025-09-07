// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

public protocol InMemoryStorageDataSource: AnyObject {
    var storageError: ((String) -> Void)? { get set }
    
    // MARK: - Passwords
    
    func createItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: String,
        contentVersion: Int,
        content: Data
    )
    
    func updateItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: String,
        contentVersion: Int,
        content: Data
    )
    
    func batchUpdateRencryptedPasswords(_ passwords: [RawItemData], date: Date)
    
    func getPasswordEntity(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> RawItemData?
    
    func listPasswords(
        options: PasswordListOptions
    ) -> [RawItemData]
    
    func deletePassword(itemID: ItemID)
    func deleteAllPasswordEntities()
    
    // MARK: - Tags
    
    func createTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    )
    
    func updateTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    )
    
    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date)
    
    func getTagEntity(
        tagID: ItemTagID
    ) -> ItemTagData?
    
    func listTags(
        options: TagListOptions
    ) -> [ItemTagData]
    
    func deleteTag(tagID: ItemTagID)
    func deleteAllTagEntities()
    
    // MARK: - Other
    
    func listUsernames() -> [String]
    func warmUp()
    func save()
}
