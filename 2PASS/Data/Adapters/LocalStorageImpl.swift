// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

final class LocalStorageImpl {
    private let passwordInteractor: PasswordInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let mainRepository: MainRepository
    
    init(
        passwordInteractor: PasswordInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        mainRepository: MainRepository
    ) {
        self.passwordInteractor = passwordInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.mainRepository = mainRepository
    }
}

extension LocalStorageImpl: LocalStorage {
    func save() {
        passwordInteractor.saveStorage()
    }
    
    func listPasswords() -> [PasswordData] {
        passwordInteractor.listPasswords(searchPhrase: nil, sortBy: .newestFirst, trashed: .no)
    }
    
    func listAllDeletedItems() -> [DeletedItemData] {
        deletedItemsInteractor.listDeletedItems()
    }
    
    func listAllTags() -> [ItemTagData] {
        passwordInteractor.listAllTags()
    }
    
    func listTrashedPasswords() -> [PasswordData] {
        passwordInteractor.listTrashedPasswords()
    }
    
    func createDeletedItem(_ deletedItem: DeletedItemData) {
        deletedItemsInteractor.createDeletedItem(
            id: deletedItem.itemID,
            kind: deletedItem.kind,
            deletedAt: deletedItem.deletedAt
        )
    }
    
    func moveFromTrash(_ passwordID: PasswordID) {
        passwordInteractor.markAsNotTrashed(for: passwordID)
    }
    
    func updateDeletedItem(_ deletedItem: DeletedItemData) {
        deletedItemsInteractor.updateDeletedItem(
            id: deletedItem.itemID,
            kind: deletedItem.kind,
            deletedAt: deletedItem.deletedAt
        )
    }
    
    func createPassword(_ password: PasswordData) {
        _ = passwordInteractor.createPasswordWithEncryptedPassword(
            passwordID: password.passwordID,
            name: password.name,
            username: password.username,
            encryptedPassword: password.password,
            notes: password.notes,
            creationDate: password.creationDate,
            modificationDate: password.modificationDate,
            iconType: password.iconType,
            trashedStatus: password.trashedStatus,
            protectionLevel: password.protectionLevel,
            uris: password.uris,
            tagIds: password.tagIds
        )
    }
    
    func updatePassword(_ password: PasswordData) {
        _ = passwordInteractor.updatePasswordWithEncryptedPassword(
            for: password.passwordID,
            name: password.name,
            username: password.username,
            encryptedPassword: password.password,
            notes: password.notes,
            modificationDate: password.modificationDate,
            iconType: password.iconType,
            trashedStatus: password.trashedStatus,
            protectionLevel: password.protectionLevel,
            uris: password.uris,
            tagIds: password.tagIds
        )
    }
    
    func removeDeletedItem(_ deletedItem: DeletedItemID) {
        deletedItemsInteractor.deleteDeletedItem(id: deletedItem)
    }
    
    func createTag(_ tag: ItemTagData) {
        passwordInteractor.createTag(data: tag)
    }
    
    func updateTag(_ tag: ItemTagData) {
        passwordInteractor.updateTag(data: tag)
    }
    
    func removeTag(_ tagID: ItemTagID) {
        passwordInteractor.deleteTag(tagID: tagID)
    }
    
    func removePassword(_ passwordID: PasswordID) {
        passwordInteractor.markAsTrashed(for: passwordID)
    }
    
    func currentVault() -> VaultEncryptedData? {
        mainRepository.selectedVault
    }
}
