// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(LogEntryEntity)
final class LogEntryEntity: NSManagedObject {
    @nonobjc private static let entityName = "LogEntryEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        content: String,
        timestamp: Date,
        module: Int,
        severity: Int
    ) {
        let log = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! LogEntryEntity
        
        log.content = content
        log.timestamp = timestamp
        log.module = Int16(module)
        log.severity = Int16(severity)
    }
    
    @nonobjc static func removeAll(on context: NSManagedObjectContext) {
        let all = listAll(on: context)
        remove(on: context, objects: all)
    }
    
    @nonobjc static func remove(on context: NSManagedObjectContext, objects: [NSManagedObject]) {
        objects.forEach { context.delete($0) }
    }
    
    @nonobjc static func listAll(
        on context: NSManagedObjectContext,
        quickFetch: Bool = false,
        ascending: Bool = false
    ) -> [LogEntryEntity] {
        let key = "timestamp"
        let fetchRequest = LogEntryEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: key, ascending: ascending)]
        fetchRequest.includesPendingChanges = true
        fetchRequest.returnsObjectsAsFaults = false
        
        if quickFetch {
            fetchRequest.propertiesToFetch = [key]
        }
        
        var list: [LogEntryEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            Log("LogEntryEntity in Storage listAll(): \(err.localizedDescription)", module: .storage)
            return []
        }
        
        return list
    }
    
    @nonobjc static func count(on context: NSManagedObjectContext) -> Int {
        let fetchRequest = LogEntryEntity.fetchRequest()
        fetchRequest.includesPendingChanges = true
        var result: Int?
        
        do {
            result = try context.count(for: fetchRequest)
        } catch {
            let err = error as NSError
            Log("LogEntryEntity in Storage, count error: \(err.localizedDescription)", module: .storage)
        }
        
        return result ?? 0
    }
}

