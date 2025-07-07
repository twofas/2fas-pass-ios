// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Storage

extension MainRepositoryImpl {
    
    // MARK: Passwords
    
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
    ) {
        inMemoryStorage?.createPassword(
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
            uris: uris,
            tagIds: tagIds
        )
    }
    
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
    ) {
        inMemoryStorage?.updatePassword(
            passwordID: passwordID,
            name: name,
            username: username,
            password: password,
            notes: notes,
            modificationDate: modificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            uris: uris,
            tagIds: tagIds
        )
    }
    
    func updatePasswords(_ passwords: [PasswordData]) {
        passwords.forEach {
            inMemoryStorage?.updatePassword(
                passwordID: $0.passwordID,
                name: $0.name,
                username: $0.username,
                password: $0.password,
                notes: $0.notes,
                modificationDate: $0.modificationDate,
                iconType: $0.iconType,
                trashedStatus: $0.trashedStatus,
                protectionLevel: $0.protectionLevel,
                uris: $0.uris,
                tagIds: $0.tagIds
            )
        }
    }
    
    func passwordsBatchUpdate(_ passwords: [PasswordData]) {
        inMemoryStorage?.batchUpdateRencryptedPasswords(passwords, date: currentDate)
    }
    
    func getPasswordEntity(
        passwordID: PasswordID,
        checkInTrash: Bool
    ) -> PasswordData? {
        inMemoryStorage?.getPasswordEntity(passwordID: passwordID, checkInTrash: checkInTrash)
    }
    
    func listPasswords(
        options: PasswordListOptions
    ) -> [PasswordData] {
        inMemoryStorage?.listPasswords(options: options) ?? []
    }
    
    func listTrashedPasswords() -> [PasswordData] {
        inMemoryStorage?.listPasswords(options: .allTrashed) ?? []
    }
    
    func deletePassword(passwordID: PasswordID) {
        inMemoryStorage?.deletePassword(passwordID: passwordID)
    }
    
    func deleteAllPasswords() {
        inMemoryStorage?.deleteAllPasswordEntities()
    }
    
    // MARK: Tags
    
    func createTag(_ tag: ItemTagData) {
        inMemoryStorage?
            .createTag(
                tagID: tag.tagID,
                name: tag.name,
                modificationDate: tag.modificationDate,
                position: Int16(tag.position),
                vaultID: tag.vaultID,
                color: tag.color
            )
    }
    
    func updateTag(_ tag: ItemTagData) {
        inMemoryStorage?.updateTag(
            tagID: tag.tagID,
            name: tag.name,
            modificationDate: tag.modificationDate,
            position: Int16(tag.position),
            vaultID: tag.vaultID,
            color: tag.color)
    }
    
    func deleteTag(tagID: ItemTagID) {
        inMemoryStorage?.deleteTag(tagID: tagID)
    }
    
    func listTags(options: TagListOptions) -> [ItemTagData] {
        inMemoryStorage?.listTags(options: options) ?? []
    }
    
    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date) {
        inMemoryStorage?.batchUpdateRencryptedTags(tags, date: date)
    }
    
    // MARK: Other
    
    func saveStorage() {
        Log("Save In-memory Storage", module: .mainRepository)
        inMemoryStorage?.save()
    }
    
    func listUsernames() -> [String] {
        inMemoryStorage?.listUsernames() ?? []
    }
    
    func createInMemoryStorage() {
        inMemoryStorage = InMemoryStorageDataSourceImpl()
        inMemoryStorage?.warmUp()
        inMemoryStorage?.storageError = { [weak self] in self?.storageError?($0) }
    }
    
    func destroyInMemoryStorage() {
        inMemoryStorage = nil
    }
    
    var hasInMemoryStorage: Bool {
        inMemoryStorage != nil
    }
}
