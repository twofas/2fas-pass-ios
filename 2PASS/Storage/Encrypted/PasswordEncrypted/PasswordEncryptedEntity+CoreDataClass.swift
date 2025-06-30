// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

final class PasswordEncryptedEntity: NSManagedObject {
    @nonobjc private static let entityName = "PasswordEncryptedEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
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
        uris: PasswordEncryptedURIs?,
        tagIds: [ItemTagID]?
    ) -> PasswordEncryptedEntity {
        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! PasswordEncryptedEntity
            
            entity.passwordID = passwordID
            entity.name = name
            entity.username = username
            entity.password = password
            entity.notes = notes
            
            entity.creationDate = creationDate
            entity.modificationDate = modificationDate
            
            entity.iconType = iconType.value
            switch iconType {
            case .domainIcon(let domain):
                entity.iconDomain = domain
            case .customIcon(let url):
                entity.iconCustomURL = url
            case .label(let labelTitle, let labelColor):
                entity.labelTitle = labelTitle
                entity.labelColor = labelColor?.hexString
            }
            
            switch trashedStatus {
            case .no:
                entity.isTrashed = false
            case .yes(let trashingDate):
                entity.isTrashed = true
                entity.trashingDate = trashingDate
            }
            
            entity.level = protectionLevel.rawValue
            
            entity.uris = uris?.uris
            entity.urisMatching = uris?.match.map({ $0.rawValue })
            entity.tagIds = tagIds
            
            return entity
        }
    }
    
    @discardableResult
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        for passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        modificationDate: Date,
        iconType: PasswordEncryptedIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: PasswordEncryptedURIs?,
        tagIds: [ItemTagID]?
    ) -> PasswordEncryptedEntity? {
        context.performAndWait {
            guard let entity = getEntity(on: context, passwordID: passwordID) else {
                Log("Can't find encrypted entity for passwordID: \(passwordID)", module: .storage)
                return nil
            }
            
            update(
                on: context,
                entity: entity,
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
            
            return entity
        }
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        entity: PasswordEncryptedEntity,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        modificationDate: Date,
        iconType: PasswordEncryptedIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: PasswordEncryptedURIs?,
        tagIds: [ItemTagID]?
    ) {
        entity.name = name
        entity.username = username
        entity.password = password
        entity.notes = notes
        
        entity.modificationDate = modificationDate
        
        entity.iconType = iconType.value
        switch iconType {
        case .domainIcon(let domain):
            entity.iconDomain = domain
        case .customIcon(let url):
            entity.iconCustomURL = url
        case .label(let labelTitle, let labelColor):
            entity.labelTitle = labelTitle
            entity.labelColor = labelColor?.hexString
        }
        
        switch trashedStatus {
        case .no:
            entity.isTrashed = false
        case .yes(let trashingDate):
            entity.isTrashed = true
            entity.trashingDate = trashingDate
        }
        
        entity.level = protectionLevel.rawValue
        
        entity.uris = uris?.uris
        entity.urisMatching = uris?.match.map({ $0.rawValue })
        entity.tagIds = tagIds
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        passwordID: PasswordID
    ) -> PasswordEncryptedEntity? {
        let fetchRequest = PasswordEncryptedEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "passwordID == %@", passwordID as CVarArg)
        fetchRequest.includesPendingChanges = true
        
        var list: [PasswordEncryptedEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("PasswordEncryptedEntity in Storage listItems: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return nil
        }
        
        // If something went wrong (wrong migration, some bugs) -> remove duplicated entries instead of:
        if list.count > 1 {
            Log("PasswordEncryptedEntity: Error while fetching entity with PasswordID: \(passwordID). There's more than one. Correcting!", severity: .error)
            let itemsForDeletition = list[1...]
            for item in itemsForDeletition {
                delete(on: context, entity: item)
            }
        }
        
        return list.first
    }
    
    @nonobjc static func deleteAllEncryptedPasswords(on context: NSManagedObjectContext, vaultID: VaultID?) {
        let items = listItems(
            on: context,
            predicate: NSPredicate(format: "isTrashed == FALSE"),
            includesPropertyValues: false,
            vaultID: vaultID
        )
        
        items.forEach { entity in
            context.delete(entity)
        }
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        predicate: NSPredicate? = nil,
        includesPropertyValues: Bool = true,
        vaultID: VaultID? = nil
    ) -> [PasswordEncryptedEntity] {
        let fetchRequest = PasswordEncryptedEntity.fetchRequest()
        fetchRequest.includesPropertyValues = includesPropertyValues
        if let predicate {
            if let vaultID {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    predicate,
                    NSPredicate(format: "vault.vaultID == %@", vaultID as CVarArg)
                ])
            } else {
                fetchRequest.predicate = predicate
            }
        }
        
        var list: [PasswordEncryptedEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("PasswordEncryptedEntity in Storage listItems: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }
        
        return list
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        excludeProtectionLevels: Set<PasswordProtectionLevel>,
        vaultID: VaultID? = nil
    ) -> [PasswordEncryptedEntity] {
        listItems(
            on: context,
            predicate:  NSPredicate(format: "NOT (level IN %@)", excludeProtectionLevels.map({ $0.rawValue })),
            vaultID: vaultID
        )
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, entity: PasswordEncryptedEntity) {
        Log("PasswordEncryptedEntity: Deleting entity of type: \(entity)", module: .storage, obfuscate: true)
        context.delete(entity)
    }
}
