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
    static func create(from data: ItemTagEncryptedData, on context: NSManagedObjectContext) -> TagEncryptedEntity {
        let entity = TagEncryptedEntity(context: context)
        entity.tagID = data.id
        entity.vaultID = data.vaultID
        entity.update(with: data)
        return entity
    }
    
    static func find(id: ItemTagID, on context: NSManagedObjectContext) -> TagEncryptedEntity? {
        let request = TagEncryptedEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(TagEncryptedEntity.tagID), id as CVarArg)
        request.fetchLimit = 1
        
        do {
            guard let result = try context.fetch(request).first else {
                return nil
            }
            return result
        } catch {
            let err = error as NSError
            Log("TagEncryptedEntity in Storage find: \(err.localizedDescription)", module: .storage)
            return nil
        }
    }
    
    static func list(on context: NSManagedObjectContext, in vaultID: VaultID) -> [TagEncryptedEntity] {
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
}

extension TagEncryptedEntity {
    
    func update(with data: ItemTagEncryptedData) {
        guard data.tagID == tagID, data.vaultID == vaultID else {
            return
        }
        
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
