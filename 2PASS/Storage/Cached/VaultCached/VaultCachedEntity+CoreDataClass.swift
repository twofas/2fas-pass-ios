// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

final class VaultCachedEntity: NSManagedObject {
    @nonobjc private static let entityName = "VaultCachedEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! VaultCachedEntity
        
        entity.vaultID = vaultID
        entity.name = name
        
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        
        entity.metadata = metadata
        
        entity.deviceNames = deviceNames
        entity.deviceID = deviceID
        entity.schemaVersion = schemaVersion
        entity.seedHash = seedHash
        entity.reference = reference
        entity.kdfSpec = kdfSpec
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        guard let entity = getEntity(on: context, vaultID: vaultID) else {
            Log("VaultCachedEntity: Can't find entity for vaultID: \(vaultID)", module: .storage, severity: .error)
            return
        }
        
        entity.name = name
        
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        
        entity.metadata = metadata
        
        entity.deviceNames = deviceNames
        entity.deviceID = deviceID
        entity.schemaVersion = schemaVersion
        entity.seedHash = seedHash
        entity.reference = reference
        entity.kdfSpec = kdfSpec
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        vaultID: UUID
    ) -> VaultCachedEntity? {
        let list = listItems(on: context)
        
        // If something went wrong (wrong migration, some bugs) -> remove duplicated entries instead of:
        if list.count > 1 {
            let itemsForDeletition = list[1...]
            for item in itemsForDeletition {
                delete(on: context, entity: item)
            }
        }
        
        return list.first
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext
    ) -> [VaultCachedEntity] {
        let fetchRequest = VaultCachedEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(
                key: #keyPath(VaultCachedEntity.name),
                ascending: true,
                selector: #selector(NSString.localizedStandardCompare)
            )
        ]
        
        fetchRequest.includesPendingChanges = true
        
        var list: [VaultCachedEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("VaultCachedEntity in Storage listItems: \(err.localizedDescription)", module: .storage, severity: .error)
            // swiftlint:enable line_length
            return []
        }
        
        return list
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, entity: VaultCachedEntity) {
        Log("VaultCachedEntity: Deleting entity of type: VaultCachedEntity", module: .storage, save: false)
        context.delete(entity)
    }
}
