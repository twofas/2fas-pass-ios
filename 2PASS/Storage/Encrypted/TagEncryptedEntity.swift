// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CoreData
import Common

final class TagEncryptedEntity: NSManagedObject {}


extension TagEncryptedEntity {
    @nonobjc static let entityName = "TagEncryptedEntity"
    @nonobjc static func fetchRequest() -> NSFetchRequest<TagEncryptedEntity> {
        NSFetchRequest<TagEncryptedEntity>(entityName: entityName)
    }
    
    @NSManaged var tagID: ItemTagID
    @NSManaged var name: Data
    @NSManaged var modificationDate: Date
    @NSManaged var position: Int16
    @NSManaged var color: String?
    @NSManaged var vaultID: VaultID
}

extension TagEncryptedEntity : Identifiable {}

extension TagEncryptedEntity {
    
    @discardableResult
    @nonobjc static func create(from data: ItemTagEncryptedData, on context: NSManagedObjectContext) -> TagEncryptedEntity {
        let entity = TagEncryptedEntity(context: context)
        entity.tagID = data.id
        entity.vaultID = data.vaultID
        entity.setData(data)
        return entity
    }
    
    @discardableResult
    @nonobjc static func update(from data: ItemTagEncryptedData, on context: NSManagedObjectContext) -> TagEncryptedEntity? {
        guard let entity = find(tagID: data.tagID, on: context),
              data.tagID == entity.tagID,
              data.vaultID == entity.vaultID else {
            return nil
        }
        entity.update(from: data)
        return entity
    }
    
    @discardableResult
    @nonobjc func update(from data: ItemTagEncryptedData) -> TagEncryptedEntity? {
        setData(data)
        return self
    }
    
    @nonobjc static func find(tagID: ItemTagID, on context: NSManagedObjectContext) -> TagEncryptedEntity? {
        let request = TagEncryptedEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(TagEncryptedEntity.tagID), tagID as CVarArg)
        request.fetchLimit = 1
        
        do {
            let result = try context.fetch(request)
            
            if result.count > 1 {
                Log("TagEncryptedEntity: Error while fetching entity with TagID: \(tagID). There's more than one. Correcting!", severity: .error)
                let itemsForDeletition = result[1...]
                for item in itemsForDeletition {
                    delete(on: context, entity: item)
                }
            }
            
            return result.first
        } catch {
            let err = error as NSError
            Log("TagEncryptedEntity in Storage find: \(err.localizedDescription)", module: .storage)
            return nil
        }
    }
    
    @nonobjc static func list(on context: NSManagedObjectContext, in vaultID: VaultID) -> [TagEncryptedEntity] {
        let request = TagEncryptedEntity.fetchRequest()
        request.predicate = NSPredicate(format: "vaultID == %@", vaultID as CVarArg)
        do {
            return try context.fetch(request)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("TagEncryptedEntity in Storage list: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, tagID: ItemTagID) {
        guard let entity = find(tagID: tagID, on: context) else { return }
        context.delete(entity)
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, entity: TagEncryptedEntity) {
        context.delete(entity)
    }
}

extension TagEncryptedEntity {
    
    @nonobjc func setData(_ data: ItemTagEncryptedData) {
        self.name = data.name
        self.modificationDate = data.modificationDate
        self.color = data.color
        self.position = Int16(data.position)
    }
}

extension ItemTagEncryptedData {
    
    init(_ entity: TagEncryptedEntity) {
        self.init(
            tagID: entity.tagID,
            vaultID: entity.vaultID,
            name: entity.name,
            color: entity.color,
            position: Int(entity.position),
            modificationDate: entity.modificationDate
        )
    }
}
