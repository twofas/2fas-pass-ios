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
    
    func createPassword(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    )
    
    func updatePassword(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    )
    
    func batchUpdateRencryptedPasswords(_ passwords: [PasswordData], date: Date)
    
    func getPasswordEntity(
        passwordID: PasswordID,
        checkInTrash: Bool
    ) -> PasswordData?
    
    func listPasswords(
        options: PasswordListOptions
    ) -> [PasswordData]
    
    func deletePassword(passwordID: PasswordID)
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
    
    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date, vaultID: VaultID)
    
    func getTagEntity(
        tagID: ItemTagID
    ) -> ItemTagData?
    
    func listTags(
        options: TagListOptions
    ) -> [ItemTagData]
    
    func deleteTag(tagID: ItemTagID)
    func deleteAllTagEntities(for vaultID: VaultID)
    
    // MARK: - Other
    
    func listUsernames() -> [String]
    func warmUp()
    func save()
}
