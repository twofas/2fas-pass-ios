// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CoreData

public final class InMemoryStorageDataSourceImpl {
    private let coreDataStack: CoreDataStack
    
    public var storageError: ((String) -> Void)?
    
    var context: NSManagedObjectContext {
        coreDataStack.context
    }
    
    public init() {
        self.coreDataStack = CoreDataStack(
            readOnly: false,
            name: "TwoPass",
            bundle: Bundle(for: InMemoryStorageDataSourceImpl.self),
            isPersistent: false
        )
        coreDataStack.logError = { Log($0, module: .storage) }
        coreDataStack.presentErrorToUser = { [weak self] in self?.storageError?($0) }
    }
}

extension InMemoryStorageDataSourceImpl: InMemoryStorageDataSource {
    public func createPassword(
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
        PasswordEntity.create(
            on: context,
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
    
    public func updatePassword(
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
        PasswordEntity.update(
            on: context,
            for: passwordID,
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
    
    public func batchUpdateRencryptedPasswords(_ passwords: [PasswordData], date: Date) {
        let listAll = PasswordEntity.listItems(on: context, options: .all)
        for pass in passwords {
            if let entity = listAll.first(where: { $0.passwordID == pass.passwordID }) {
                PasswordEntity.update(
                    on: context,
                    entity: entity,
                    name: pass.name,
                    username: pass.username,
                    password: pass.password,
                    notes: pass.notes,
                    modificationDate: date,
                    iconType: pass.iconType,
                    trashedStatus: pass.trashedStatus,
                    protectionLevel: pass.protectionLevel,
                    uris: pass.uris,
                    tagIds: pass.tagIds
                )
            } else {
                Log("Error while searching for Password Entity \(pass.passwordID)")
            }
        }
    }
    
    public func getPasswordEntity(
        passwordID: PasswordID,
        checkInTrash: Bool
    ) -> PasswordData? {
        PasswordEntity.getEntity(
            on: context,
            passwordID: passwordID,
            checkInTrash: checkInTrash
        )?.toData()
    }
    
    public func listPasswords(
        options: PasswordListOptions
    ) -> [PasswordData] {
        PasswordEntity.listItems(on: context, options: options)
            .map { $0.toData() }
    }
    
    public func deletePassword(passwordID: PasswordID) {
        guard let entity = PasswordEntity.getEntity(
            on: context,
            passwordID: passwordID,
            checkInTrash: true
        ) else { return }
        PasswordEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllPasswordEntities() {
        PasswordEntity.deleteAllPasswordEntities(on: context)
    }
}

extension InMemoryStorageDataSourceImpl {
    public func createTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    ) {
        TagEntity
            .create(
                on: context,
                tagID: tagID,
                name: name,
                modificationDate: modificationDate,
                position: position,
                vaultID: vaultID,
                color: color
            )
    }
    
    public func updateTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    ) {
        TagEntity
            .update(
                on: context,
                tagID: tagID,
                name: name,
                modificationDate: modificationDate,
                position: position,
                vaultID: vaultID,
                color: color
            )
    }
    
    public func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date, vaultID: VaultID) {
        let listAll = TagEntity.listItems(on: context, options: .all(vaultID))
        for tag in tags {
            if let entity = listAll.first(where: { $0.tagID == tag.id }) {
                TagEntity
                    .update(
                        on: context,
                        entity: entity,
                        name: tag.name,
                        modificationDate: date,
                        position: Int16(tag.position),
                        vaultID: tag.vaultID,
                        color: tag.color?.hexString
                    )
            } else {
                Log("Error while searching for Tag Entity \(tag.id)")
            }
        }
    }
    
    public func getTagEntity(
        tagID: ItemTagID
    ) -> ItemTagData? {
        TagEntity.getEntity(on: context, tagID: tagID)?
            .toData()
    }
    
    public func listTags(
        options: TagListOptions
    ) -> [ItemTagData] {
        TagEntity.listItems(on: context, options: options)
            .map { $0.toData() }
    }
    
    public func deleteTag(tagID: ItemTagID) {
        guard let entity = TagEntity.getEntity(on: context, tagID: tagID) else {
            return
        }
        TagEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllTagEntities(for vaultID: VaultID) {
        TagEntity.deleteAllTagEntities(on: context, vaultID: vaultID)
    }
}

extension InMemoryStorageDataSourceImpl {
    public func listUsernames() -> [String] {
        PasswordEntity.listItems(on: context, options: .allNotTrashed)
            .compactMap { $0.username }
    }
    
    public func warmUp() {
        // Artifically calling out context so it will prepare storage for concurrent access
        try? coreDataStack.context.save()
    }
    
    public func save() {
        coreDataStack.save()
    }
}
