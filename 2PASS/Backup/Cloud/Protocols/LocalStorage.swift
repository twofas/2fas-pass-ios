// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol LocalStorage: AnyObject {
    func save()
    func listPasswords() -> [PasswordData]
    func listAllDeletedItems() -> [DeletedItemData]
    func listAllTags() -> [ItemTagData]
    func moveFromTrash(_ passwordID: PasswordID)
    func listTrashedPasswords() -> [PasswordData]
    func createDeletedItem(_ deletedItem: DeletedItemData)
    func updateDeletedItem(_ deletedItem: DeletedItemData)
    func createPassword(_ password: PasswordData)
    func updatePassword(_ password: PasswordData)
    func createTag(_ tag: ItemTagData)
    func updateTag(_ tag: ItemTagData)
    func removeDeletedItem(_ deletedItemID: DeletedItemID)
    func removeTag(_ tagID: ItemTagID)
    func removePassword(_ passwordID: PasswordID)
    func currentVault() -> VaultEncryptedData?
}
