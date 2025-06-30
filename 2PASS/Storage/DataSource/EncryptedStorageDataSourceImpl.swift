// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CoreData

public final class EncryptedStorageDataSourceImpl {
    private let coreDataStack: CoreDataStack
    
    public var storageError: ((String) -> Void)?
    
    var context: NSManagedObjectContext {
        coreDataStack.context
    }
    
    public init() {
        self.coreDataStack = CoreDataStack(
            readOnly: false,
            name: "ColdStorage",
            bundle: Bundle(for: EncryptedStorageDataSourceImpl.self),
            storeInGroup: true,
            isPersistent: true
        )
        coreDataStack.logError = { Log($0, module: .storage) }
        coreDataStack.presentErrorToUser = { [weak self] in self?.storageError?($0) }
    }
}

extension EncryptedStorageDataSourceImpl: EncryptedStorageDataSource {
    
    // MARK: Encrypted Passwords
    
    public func createEncryptedPassword(
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
        let entity = PasswordEncryptedEntity.create(
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
        guard let vault = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID) else { return }
        vault.addToPasswords(entity)
    }
    
    public func updateEncryptedPassword(
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
        let entity = PasswordEncryptedEntity.update(
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
        guard let vault = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID), let entity else { return }
        vault.addToPasswords(entity)
    }
    
    public func batchUpdateRencryptedPasswords(_ passwords: [PasswordEncryptedData], date: Date) {
        guard let currentVaultID = passwords.first?.vaultID else {
            Log("Error while getting current vaultID for batch update")
            return
        }
        let listAll = PasswordEncryptedEntity.listItems(on: context, vaultID: currentVaultID)
        for pass in passwords {
            if let entity = listAll.first(where: { $0.passwordID == pass.passwordID }) {
                PasswordEncryptedEntity.update(
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
                Log("Error while searching for Password Encrypted Entity \(pass.passwordID)")
            }
        }
    }
    
    public func getEncryptedPasswordEntity(passwordID: PasswordID) -> PasswordEncryptedData? {
        PasswordEncryptedEntity.getEntity(on: context, passwordID: passwordID)?
            .toData()
    }
    
    public func listEncryptedPasswords(in vaultID: VaultID) -> [PasswordEncryptedData] {
        listEncryptedPasswords(in: vaultID, excludeProtectionLevels: [])
    }
    
    public func listEncryptedPasswords(in vaultID: VaultID, excludeProtectionLevels: Set<PasswordProtectionLevel>) -> [PasswordEncryptedData] {
        guard let vault = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID) else { return [] }
        
        if excludeProtectionLevels.isEmpty {
            return VaultEncryptedEntity.listPasswords(on: context, vault: vault).map({ $0.toData() })
        } else {
            return PasswordEncryptedEntity.listItems(on: context, excludeProtectionLevels: excludeProtectionLevels, vaultID: vaultID)
                .map({ $0.toData() })
        }
    }
    
    public func addEncryptedPassword(_ passwordID: PasswordID, to vaultID: VaultID) {
        guard let entity = PasswordEncryptedEntity.getEntity(on: context, passwordID: passwordID),
              let vault = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID)
        else { return }
        vault.addToPasswords(entity)
    }
    
    public func deleteEncryptedPassword(passwordID: PasswordID) {
        guard let entity = PasswordEncryptedEntity.getEntity(on: context, passwordID: passwordID) else { return }
        PasswordEncryptedEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllEncryptedPasswords(in vaultID: VaultID?) {
        PasswordEncryptedEntity.deleteAllEncryptedPasswords(on: context, vaultID: vaultID)
    }
    
    // MARK: Encrypted Vaults
    
    public func listEncrypteVaults() -> [VaultEncryptedData] {
        VaultEncryptedEntity.listItems(on: context)
            .map { $0.toData() }
    }
    
    public func getEncryptedVault(for vaultID: VaultID) -> VaultEncryptedData? {
        VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID)?
            .toData()
    }
    
    public func createEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        VaultEncryptedEntity.create(
            on: context,
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    public func updateEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        VaultEncryptedEntity.update(
            on: context,
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    public func deleteEncryptedVault(_ vaultID: VaultID) {
        guard let entity = VaultEncryptedEntity.getEntity(on: context, vaultID: vaultID) else { return }
        VaultEncryptedEntity.delete(on: context, entity: entity)
    }
    
    public func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        DeletedItemEncryptedEntity.create(
            on: context,
            itemID: id,
            kind: kind,
            deletedAt: deletedAt,
            vaultID: vaultID
        )
    }
    
    public func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        DeletedItemEncryptedEntity.update(
            on: context,
            itemID: id,
            kind: kind,
            deletedAt: deletedAt,
            vaultID: vaultID
        )
    }
    
    public func listDeletedItems(in vaultID: VaultID, limit: Int?) -> [DeletedItemData] {
        DeletedItemEncryptedEntity.listItems(on: context, vaultID: vaultID, limit: limit)
            .map({ $0.toData })
    }
    
    public func deleteDeletedItem(id: DeletedItemID) {
        guard let entity = DeletedItemEncryptedEntity.getEntity(on: context, itemID: id) else {
            return
        }
        DeletedItemEncryptedEntity.delete(on: context, entity: entity)
    }
    
    public func createEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        WebBrowserEncryptedEntity.create(from: data, on: context)
    }
    
    public func listEncryptedWebBrowsers() -> [WebBrowserEncryptedData] {
        WebBrowserEncryptedEntity.list(on: context)
            .map(WebBrowserEncryptedData.init)
    }
    
    public func updateEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        guard let entity = WebBrowserEncryptedEntity.find(id: data.id, on: context) else {
            Log("No entity available to update WebBrowserEncryptedEntity", module: .storage)
            return
        }
        entity.update(with: data)
    }
    
    public func deleteEncryptedWebBrowser(id: UUID) {
        guard let entity = WebBrowserEncryptedEntity.find(id: id, on: context) else {
            Log("No entity available to delete WebBrowserEncryptedEntity", module: .storage)
            return
        }
        context.delete(entity)
    }
    
    public func createEncryptedTag(_ tag: ItemTagEncryptedData) {
        TagEncryptedEntity.create(from: tag, on: context)
    }
    
    public func updateEncryptedTag(_ tag: ItemTagEncryptedData) {
        guard let entity = TagEncryptedEntity.find(id: tag.id, on: context) else {
            Log("No entity available to update TagEncryptedEntity", module: .storage)
            return
        }
        entity.update(with: tag)
    }
    
    public func deleteEncryptedTag(id: ItemTagID) -> Bool {
        guard let entity = TagEncryptedEntity.find(id: id, on: context) else {
            Log("No entity available to delete TagEncryptedEntity", module: .storage)
            return false
        }
        context.delete(entity)
        return true
    }
    
    public func listEncryptedTags(in vaultID: VaultID) -> [ItemTagEncryptedData] {
        TagEncryptedEntity.list(on: context, in: vaultID)
            .map(ItemTagEncryptedData.init)
    }
    
    public func warmUp() {
        // Artifically calling out context so it will prepare storage for concurrent access
        coreDataStack.context.performAndWait { [weak self] in
            try? self?.coreDataStack.context.save()
        }
    }
    
    public func save() {
        coreDataStack.save()
    }
}
