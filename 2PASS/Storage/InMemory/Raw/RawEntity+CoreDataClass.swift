// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(RawEntity)
final class RawEntity: ItemMetadataEntity {
    @nonobjc static let loginEntityName = "RawEntity"
    
    @nonobjc static func createRaw(
        on context: NSManagedObjectContext,
        itemID: ItemID,
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
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! RawEntity
        
        entity.itemID = itemID
        entity.name = name
        entity.creationDate = creationDate
        entity.modificationDate = modificationDate
        entity.contentType = ItemContentType.login.rawValue
        entity.contentVersion = Int16(LoginItemContent.contentVersion)
        
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
        
        entity.contentType = contentType.rawValue
        entity.contentVersion = Int16(contentVersion)
        entity.content = content
    }
    
    @nonobjc static func updateRaw(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        guard let entity = getRawEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find raw entity for itemID: \(itemID)", module: .storage)
            return
        }
        
        updateRaw(
            on: context,
            entity: entity,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content
        )
    }
    
    @nonobjc static func updateRaw(
        on context: NSManagedObjectContext,
        entity: RawEntity,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
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
        
        entity.contentType = contentType.rawValue
        entity.contentVersion = Int16(contentVersion)
        entity.content = content
    }
    
    @nonobjc static func getRawEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> RawEntity? {
        let fetchRequest: NSFetchRequest<RawEntity> = RawEntity.fetchRequest()
        
        if checkInTrash {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        } else {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@ AND isTrashed == false", itemID as CVarArg)
        }
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            Log("Error fetching RawEntity: \(error)", module: .storage)
            return nil
        }
    }
    
    @nonobjc static func listRawEntities(
        on context: NSManagedObjectContext,
        options: ItemsListOptions
    ) -> [RawEntity] {
        let fetchRequest: NSFetchRequest<RawEntity> = RawEntity.fetchRequest()
        fetchRequest.predicate = options.predicate
        fetchRequest.sortDescriptors = options.sortDescriptors
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            Log("Error fetching RawEntities: \(error)", module: .storage)
            return []
        }
    }
    
    override func toData() -> ItemData {
        return .raw(.init(
            id: itemID,
            metadata: toMetadata(),
            name: name,
            contentType: .unknown(contentType),
            contentVersion: Int(contentVersion),
            content: content
        ))
    }
}
