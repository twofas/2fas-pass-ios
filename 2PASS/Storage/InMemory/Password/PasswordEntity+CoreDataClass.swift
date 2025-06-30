// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(PasswordEntity)
final class PasswordEntity: NSManagedObject {
    @nonobjc static let entityName = "PasswordEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
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
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! PasswordEntity
        
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
        
        if let uris, !uris.isEmpty {
            var urisList: [String] = []
            var urisMatchingList: [String] = []
            for uri in uris {
                urisList.append(uri.uri)
                urisMatchingList.append(uri.match.rawValue)
            }
            entity.uris = urisList
            entity.urisMatching = urisMatchingList
        } else {
            entity.uris = nil
            entity.urisMatching = nil
        }
        
        if let tagIds, tagIds.isEmpty == false {
            entity.tagIds = tagIds
        } else {
            entity.tagIds = nil
        }
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        for passwordID: PasswordID,
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
        guard let entity = getEntity(on: context, passwordID: passwordID, checkInTrash: true) else {
            Log("Can't find entity for passwordID: \(passwordID)", module: .storage)
            return
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
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        entity: PasswordEntity,
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
        entity.name = name
        entity.username = username
        entity.password = password
        entity.notes = notes
        
        entity.modificationDate = modificationDate
        
        entity.iconType = iconType.value
        
        switch iconType {
        case .customIcon(let iconURI):
            entity.iconCustomURL = iconURI
        case .domainIcon(let domain):
            entity.iconDomain = domain
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
        
        if let uris, !uris.isEmpty {
            var urisList: [String] = []
            var urisMatchingList: [String] = []
            for uri in uris {
                urisList.append(uri.uri)
                urisMatchingList.append(uri.match.rawValue)
            }
            entity.uris = urisList
            entity.urisMatching = urisMatchingList
        } else {
            entity.uris = nil
            entity.urisMatching = nil
        }
        
        if let tagIds, tagIds.isEmpty == false {
            entity.tagIds = tagIds
        } else {
            entity.tagIds = nil
        }
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        passwordID: UUID,
        checkInTrash: Bool
    ) -> PasswordEntity? {
        let list = listItems(
            on: context,
            options: checkInTrash ? .findExistingByPasswordID(passwordID) : .findNotTrashedByPasswordID(passwordID)
        )
        
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
        on context: NSManagedObjectContext,
        options: PasswordListOptions
    ) -> [PasswordEntity] {
        listItems(on: context, predicate: options.predicate, sortDescriptors: options.sortDescriptors)
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, entity: PasswordEntity) {
        Log("Deleting entity of type: \(entity)", module: .storage)
        context.delete(entity)
    }
    
    @nonobjc static func deleteAllPasswordEntities(on context: NSManagedObjectContext) {
        let items = listItems(on: context, options: .allNotTrashed)
        items.forEach { item in
            context.delete(item)
        }
    }
}

private extension PasswordEntity {
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?
    ) -> [PasswordEntity] {
        let fetchRequest = PasswordEntity.fetchRequest()
        if let predicate {
            fetchRequest.predicate = predicate
        }
        if let sortDescriptors {
            fetchRequest.sortDescriptors = sortDescriptors
        }
        
        var list: [PasswordEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("PasswordEntity in Storage listItems(filter:\(String(describing: predicate)): \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }
        
        return list
    }
}
