// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(SecureNoteEntity)
final class SecureNoteEntity: ItemMetadataEntity {
    @nonobjc static let secureNoteEntityName = "SecureNoteEntity"
    
    override class func create(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        do {
            let decoder = JSONDecoder()
            let secureNoteContent = try decoder.decode(SecureNoteContent.self, from: content)

            createSecureNote(
                on: context,
                itemID: itemID,
                vaultID: vaultID,
                creationDate: creationDate,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                text: secureNoteContent.text
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    @nonobjc override static func update(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        do {
            let decoder = JSONDecoder()
            let secureNoteContent = try decoder.decode(SecureNoteContent.self, from: content)

            updateSecureNote(
                on: context,
                for: itemID,
                vaultID: vaultID,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                text: secureNoteContent.text
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    @nonobjc static func createSecureNote(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: secureNoteEntityName, into: context) as! SecureNoteEntity

        entity.itemID = itemID
        entity.vaultID = vaultID
        entity.name = name
        entity.creationDate = creationDate
        entity.modificationDate = modificationDate
        entity.contentType = ItemContentType.secureNote.rawValue
        entity.contentVersion = Int16(SecureNoteContent.contentVersion)

        switch trashedStatus {
        case .no:
            entity.isTrashed = false
        case .yes(let trashingDate):
            entity.isTrashed = true
            entity.trashingDate = trashingDate
        }

        entity.level = protectionLevel.rawValue

        if let tagIds, tagIds.isEmpty == false {
            entity.tagIds = tagIds
        } else {
            entity.tagIds = nil
        }

        entity.text = text
    }
    
    @nonobjc static func updateSecureNote(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?
    ) {
        guard let entity = getSecureNoteEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find secure note entity for itemID: \(itemID)", module: .storage)
            return
        }

        updateSecureNote(
            on: context,
            entity: entity,
            vaultID: vaultID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            text: text
        )
    }
    
    @nonobjc static func updateSecureNote(
        on context: NSManagedObjectContext,
        entity: SecureNoteEntity,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?
    ) {
        entity.vaultID = vaultID
        entity.modificationDate = modificationDate
        entity.name = name

        switch trashedStatus {
        case .no:
            entity.isTrashed = false
        case .yes(let trashingDate):
            entity.isTrashed = true
            entity.trashingDate = trashingDate
        }

        entity.level = protectionLevel.rawValue

        if let tagIds, tagIds.isEmpty == false {
            entity.tagIds = tagIds
        } else {
            entity.tagIds = nil
        }

        entity.text = text
    }
    
    @nonobjc static func getSecureNoteEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> SecureNoteEntity? {
        let fetchRequest: NSFetchRequest<SecureNoteEntity> = SecureNoteEntity.fetchRequest()
        
        if checkInTrash {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        } else {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@ AND isTrashed == false", itemID as CVarArg)
        }
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            Log("Error fetching SecureNoteEntity: \(error)", module: .storage)
            return nil
        }
    }
    
    @nonobjc static func listSecureNoteEntities(
        on context: NSManagedObjectContext,
        options: ItemsListOptions
    ) -> [SecureNoteEntity] {
        let fetchRequest: NSFetchRequest<SecureNoteEntity> = SecureNoteEntity.fetchRequest()
        fetchRequest.predicate = options.predicate
        fetchRequest.sortDescriptors = options.sortDescriptors
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            Log("Error fetching SecureNoteEntities: \(error)", module: .storage)
            return []
        }
    }
    
    override func toData() -> ItemData {
        let metadata = toMetadata()
        
        let content = SecureNoteContent(
            name: name,
            text: text
        )
        
        return .secureNote(SecureNoteItemData(
            id: itemID,
            vaultId: vaultID,
            metadata: metadata,
            name: name,
            content: content
        ))
    }
}
