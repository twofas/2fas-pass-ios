// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(WiFiEntity)
final class WiFiEntity: ItemMetadataEntity {
    @nonobjc static let wifiEntityName = "WiFiEntity"

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
            let wifiContent = try decoder.decode(WiFiContent.self, from: content)

            createWiFi(
                on: context,
                itemID: itemID,
                vaultID: vaultID,
                creationDate: creationDate,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                ssid: wifiContent.ssid,
                password: wifiContent.password,
                notes: wifiContent.notes,
                securityType: wifiContent.securityType,
                hidden: wifiContent.hidden
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
            let wifiContent = try decoder.decode(WiFiContent.self, from: content)

            updateWiFi(
                on: context,
                for: itemID,
                vaultID: vaultID,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                ssid: wifiContent.ssid,
                password: wifiContent.password,
                notes: wifiContent.notes,
                securityType: wifiContent.securityType,
                hidden: wifiContent.hidden
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    @nonobjc static func createWiFi(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        ssid: String?,
        password: Data?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: wifiEntityName, into: context) as! WiFiEntity

        entity.itemID = itemID
        entity.vaultID = vaultID
        entity.name = name
        entity.creationDate = creationDate
        entity.modificationDate = modificationDate
        entity.contentType = ItemContentType.wifi.rawValue
        entity.contentVersion = Int16(WiFiContent.contentVersion)

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

        entity.ssid = ssid
        entity.password = password
        entity.notes = notes
        entity.securityType = securityType.rawValue
        entity.hidden = hidden
    }

    @nonobjc static func updateWiFi(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        ssid: String?,
        password: Data?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    ) {
        guard let entity = getWiFiEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find WiFi entity for itemID: \(itemID)", module: .storage)
            return
        }

        updateWiFi(
            on: context,
            entity: entity,
            vaultID: vaultID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            ssid: ssid,
            password: password,
            notes: notes,
            securityType: securityType,
            hidden: hidden
        )
    }

    @nonobjc static func updateWiFi(
        on context: NSManagedObjectContext,
        entity: WiFiEntity,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        ssid: String?,
        password: Data?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
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

        entity.ssid = ssid
        entity.password = password
        entity.notes = notes
        entity.securityType = securityType.rawValue
        entity.hidden = hidden
    }

    @nonobjc static func getWiFiEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> WiFiEntity? {
        let fetchRequest: NSFetchRequest<WiFiEntity> = WiFiEntity.fetchRequest()

        if checkInTrash {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        } else {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@ AND isTrashed == false", itemID as CVarArg)
        }

        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            Log("Error fetching WiFiEntity: \(error)", module: .storage)
            return nil
        }
    }

    @nonobjc static func listWiFiEntities(
        on context: NSManagedObjectContext,
        options: ItemsListOptions
    ) -> [WiFiEntity] {
        let fetchRequest: NSFetchRequest<WiFiEntity> = WiFiEntity.fetchRequest()
        fetchRequest.predicate = options.predicate
        fetchRequest.sortDescriptors = options.sortDescriptors

        do {
            return try context.fetch(fetchRequest)
        } catch {
            Log("Error fetching WiFiEntities: \(error)", module: .storage)
            return []
        }
    }

    override func toData() -> ItemData {
        let metadata = toMetadata()
        let wifiSecurityType = WiFiContent.SecurityType(rawValue: self.securityType) ?? .none

        let content = WiFiContent(
            name: name,
            ssid: ssid?.nonBlankTrimmedOrNil,
            password: password,
            notes: notes,
            securityType: wifiSecurityType,
            hidden: hidden
        )

        return .wifi(WiFiItemData(
            id: itemID,
            vaultId: vaultID,
            metadata: metadata,
            name: name,
            content: content
        ))
    }
}
