// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common
import UIKit

@objc(LoginEntity)
final class LoginEntity: ItemMetadataEntity {
    @nonobjc static let loginEntityName = "LoginEntity"

    @nonobjc override static func create(
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
            let loginContent = try decoder.decode(LoginItemContent.self, from: content)
            
            createLogin(
                on: context,
                itemID: itemID,
                vaultID: vaultID,
                creationDate: creationDate,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                username: loginContent.username,
                password: loginContent.password,
                notes: loginContent.notes,
                iconType: loginContent.iconType,
                uris: loginContent.uris
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
            let loginContent = try decoder.decode(LoginItemContent.self, from: content)
            
            updateLogin(
                on: context,
                for: itemID,
                vaultID: vaultID,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                username: loginContent.name,
                password: loginContent.password,
                notes: loginContent.notes,
                iconType: loginContent.iconType,
                uris: loginContent.uris
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    @nonobjc static func createLogin(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: loginEntityName, into: context) as! LoginEntity
        
        entity.itemID = itemID
        entity.vaultID = vaultID
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
        
        entity.username = username
        entity.password = password
        entity.notes = notes
        
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
        
        switch iconType {
        case .domainIcon(let domain):
            entity.iconType = "domainIcon"
            entity.iconDomain = domain
        case .customIcon(let url):
            entity.iconType = "customIcon"
            entity.iconURL = url.absoluteString
        case .label(let labelTitle, let labelColor):
            entity.iconType = "label"
            entity.iconLabelTitle = labelTitle
            entity.iconColorHex = labelColor?.hexString
        }
    }
    
    @nonobjc static func updateLogin(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) {
        guard let entity = getLoginEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find login entity for itemID: \(itemID)", module: .storage)
            return
        }
        
        updateLogin(
            on: context,
            entity: entity,
            vaultID: vaultID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            username: username,
            password: password,
            notes: notes,
            iconType: iconType,
            uris: uris
        )
    }
    
    @nonobjc static func updateLogin(
        on context: NSManagedObjectContext,
        entity: LoginEntity,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
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
        
        entity.username = username
        entity.password = password
        entity.notes = notes

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
        
        switch iconType {
        case .domainIcon(let domain):
            entity.iconType = "domainIcon"
            entity.iconDomain = domain
            entity.iconURL = nil
            entity.iconLabelTitle = nil
            entity.iconColorHex = nil
        case .customIcon(let url):
            entity.iconType = "customIcon"
            entity.iconURL = url.absoluteString
            entity.iconDomain = nil
            entity.iconLabelTitle = nil
            entity.iconColorHex = nil
        case .label(let labelTitle, let labelColor):
            entity.iconType = "label"
            entity.iconLabelTitle = labelTitle
            entity.iconColorHex = labelColor?.hexString
            entity.iconDomain = nil
            entity.iconURL = nil
        }
    }
    
    @nonobjc static func getLoginEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> LoginEntity? {
        let fetchRequest: NSFetchRequest<LoginEntity> = LoginEntity.fetchRequest()
        
        if checkInTrash {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        } else {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@ AND isTrashed == false", itemID as CVarArg)
        }
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            Log("Error fetching LoginEntity: \(error)", module: .storage)
            return nil
        }
    }
    
    @nonobjc static func listLoginEntities(
        on context: NSManagedObjectContext,
        options: ItemsListOptions
    ) -> [LoginEntity] {
        let fetchRequest: NSFetchRequest<LoginEntity> = LoginEntity.fetchRequest()
        fetchRequest.predicate = options.predicate
        fetchRequest.sortDescriptors = options.sortDescriptors
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            Log("Error fetching LoginEntities: \(error)", module: .storage)
            return []
        }
    }
    
    override func toData() -> ItemData {
        let metadata = toMetadata()
        
        let iconType: PasswordIconType = {
            if self.iconType == "domainIcon" {
                return .domainIcon(iconDomain)
            } else if self.iconType == "customIcon", let urlString = iconURL, let url = URL(string: urlString) {
                return .customIcon(url)
            } else if self.iconType == "label" {
                return .label(
                    labelTitle: iconLabelTitle ?? Config.defaultIconLabel,
                    labelColor: UIColor(hexString: iconColorHex)
                )
            } else {
                return .default
            }
        }()
                
        let content = LoginItemContent(
            name: name,
            username: username,
            password: password,
            notes: notes,
            iconType: iconType,
            uris: { () -> [PasswordURI]? in
                guard let uris else { return nil }
                return uris.enumerated().map { index, uri in
                    let match: PasswordURI.Match = {
                        if let value = urisMatching?[safe: index], let match = PasswordURI.Match(rawValue: value) {
                            return match
                        }
                        return .domain
                    }()
                    return .init(uri: uri, match: match)
                }
            }()
        )
        
        return .login(LoginItemData(
            id: itemID,
            vaultId: vaultID,
            metadata: metadata,
            name: name,
            content: content
        ))
    }
}
