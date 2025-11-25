// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(CardEntity)
final class CardEntity: ItemMetadataEntity {
    @nonobjc static let cardEntityName = "CardEntity"

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
            let cardContent = try decoder.decode(CardContent.self, from: content)

            createCard(
                on: context,
                itemID: itemID,
                vaultID: vaultID,
                creationDate: creationDate,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                cardHolder: cardContent.cardHolder,
                cardNumber: cardContent.cardNumber,
                expirationDate: cardContent.expirationDate,
                securityCode: cardContent.securityCode,
                notes: cardContent.notes,
                cardNumberMask: cardContent.cardNumberMask,
                cardIssuer: cardContent.cardIssuer
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
            let cardContent = try decoder.decode(CardContent.self, from: content)

            updateCard(
                on: context,
                for: itemID,
                vaultID: vaultID,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                cardHolder: cardContent.cardHolder,
                cardNumber: cardContent.cardNumber,
                expirationDate: cardContent.expirationDate,
                securityCode: cardContent.securityCode,
                notes: cardContent.notes,
                cardNumberMask: cardContent.cardNumberMask,
                cardIssuer: cardContent.cardIssuer
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    @nonobjc static func createCard(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: cardEntityName, into: context) as! CardEntity

        entity.itemID = itemID
        entity.vaultID = vaultID
        entity.name = name
        entity.creationDate = creationDate
        entity.modificationDate = modificationDate
        entity.contentType = ItemContentType.card.rawValue
        entity.contentVersion = Int16(CardContent.contentVersion)

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

        entity.cardHolder = cardHolder
        entity.cardNumber = cardNumber
        entity.expirationDate = expirationDate
        entity.securityCode = securityCode
        entity.notes = notes
        entity.cardNumberMask = cardNumberMask
        entity.cardIssuer = cardIssuer
    }

    @nonobjc static func updateCard(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    ) {
        guard let entity = getCardEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find card entity for itemID: \(itemID)", module: .storage)
            return
        }

        updateCard(
            on: context,
            entity: entity,
            vaultID: vaultID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            cardHolder: cardHolder,
            cardNumber: cardNumber,
            expirationDate: expirationDate,
            securityCode: securityCode,
            notes: notes,
            cardNumberMask: cardNumberMask,
            cardIssuer: cardIssuer
        )
    }

    @nonobjc static func updateCard(
        on context: NSManagedObjectContext,
        entity: CardEntity,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
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

        entity.cardHolder = cardHolder
        entity.cardNumber = cardNumber
        entity.expirationDate = expirationDate
        entity.securityCode = securityCode
        entity.notes = notes
        entity.cardNumberMask = cardNumberMask
        entity.cardIssuer = cardIssuer
    }

    @nonobjc static func getCardEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> CardEntity? {
        let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()

        if checkInTrash {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        } else {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@ AND isTrashed == false", itemID as CVarArg)
        }

        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            Log("Error fetching CardEntity: \(error)", module: .storage)
            return nil
        }
    }

    @nonobjc static func listCardEntities(
        on context: NSManagedObjectContext,
        options: ItemsListOptions
    ) -> [CardEntity] {
        let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        fetchRequest.predicate = options.predicate
        fetchRequest.sortDescriptors = options.sortDescriptors

        do {
            return try context.fetch(fetchRequest)
        } catch {
            Log("Error fetching CardEntities: \(error)", module: .storage)
            return []
        }
    }

    override func toData() -> ItemData {
        let metadata = toMetadata()

        let content = CardContent(
            name: name,
            cardHolder: cardHolder,
            cardIssuer: cardIssuer,
            cardNumber: cardNumber,
            cardNumberMask: cardNumberMask,
            expirationDate: expirationDate,
            securityCode: securityCode,
            notes: notes
        )

        return .card(CardItemData(
            id: itemID,
            vaultId: vaultID,
            metadata: metadata,
            name: name,
            content: content
        ))
    }
}
