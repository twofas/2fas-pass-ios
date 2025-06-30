// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

final class PasswordCachedEntity: NSManagedObject {
    @nonobjc private static let entityName = "PasswordCachedEntity"
    
    @discardableResult
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
        vaultID: VaultID,
        metadata: Data
    ) -> PasswordCachedEntity {
        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! PasswordCachedEntity
            
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
            case .label(let labelTitle, let labelColor):
                entity.labelTitle = labelTitle
                entity.labelColor = labelColor?.hexString
            case .customIcon(let url):
                entity.iconCustomURL = url
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
            entity.vaultID = vaultID
            
            entity.metadata = metadata
            
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
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordEncryptedIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: PasswordEncryptedURIs?,
        metadata: Data
    ) -> PasswordCachedEntity? {
        context.performAndWait {
            guard let entity = getEntity(on: context, passwordID: passwordID) else {
                Log("PaswordCachedEntity: Can't find encrypted entity for passwordID: \(passwordID)", module: .storage)
                return nil
            }
            
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
                        
            entity.metadata = metadata
            
            return entity
        }
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        passwordID: PasswordID
    ) -> PasswordCachedEntity? {
        let fetchRequest = PasswordCachedEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "passwordID == %@", passwordID as CVarArg)
        fetchRequest.includesPendingChanges = true

        var list: [PasswordCachedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("PasswordCachedEntity in Storage listItems: \(err.localizedDescription)", module: .storage, severity: .error)
            // swiftlint:enable line_length
            return nil
        }

        // If something went wrong (wrong migration, some bugs) -> remove duplicated entries instead of:
        if list.count > 1 {
            let itemsForDeletition = list[1...]
            for item in itemsForDeletition {
                delete(on: context, entity: item)
            }
        }

        return list.first
    }
    
    @nonobjc static func deleteAllEncryptedPasswords(on context: NSManagedObjectContext) {
        let items = listItems(
            on: context,
            predicate: NSPredicate(format: "isTrashed == FALSE"),
            includesPropertyValues: false
        )
        
        items.forEach { entity in
            context.delete(entity)
        }
    }
    
    @nonobjc static func listItemsInVault(
        on context: NSManagedObjectContext,
        vaultID: VaultID
    ) -> [PasswordCachedEntity] {
        listItems(on: context, predicate: NSPredicate(format: "vaultID == %@", vaultID as CVarArg))
    }

    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        predicate: NSPredicate? = nil,
        includesPropertyValues: Bool = true
    ) -> [PasswordCachedEntity] {
        let fetchRequest = PasswordCachedEntity.fetchRequest()
        fetchRequest.includesPropertyValues = includesPropertyValues
        if let predicate {
            fetchRequest.predicate = predicate
        }

        var list: [PasswordCachedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("PasswordCachedEntity in Storage listItems: \(err.localizedDescription)", module: .storage, severity: .error)
            // swiftlint:enable line_length
            return []
        }

        return list
    }

    @nonobjc static func delete(on context: NSManagedObjectContext, entity: PasswordCachedEntity) {
        Log("PasswordCachedEntity: Deleting entity of type: PasswordCachedEntity", module: .storage, save: false)
        context.delete(entity)
    }
}
