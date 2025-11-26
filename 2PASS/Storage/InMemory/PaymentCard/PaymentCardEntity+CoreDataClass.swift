// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(PaymentCardEntity)
final class PaymentCardEntity: ItemMetadataEntity {
    @nonobjc static let paymentCardEntityName = "PaymentCardEntity"

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
            let paymentCardContent = try decoder.decode(PaymentCardContent.self, from: content)

            createPaymentCard(
                on: context,
                itemID: itemID,
                vaultID: vaultID,
                creationDate: creationDate,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                cardHolder: paymentCardContent.cardHolder,
                cardNumber: paymentCardContent.cardNumber,
                expirationDate: paymentCardContent.expirationDate,
                securityCode: paymentCardContent.securityCode,
                notes: paymentCardContent.notes,
                cardNumberMask: paymentCardContent.cardNumberMask,
                cardIssuer: paymentCardContent.cardIssuer
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
            let paymentCardContent = try decoder.decode(PaymentCardContent.self, from: content)

            updatePaymentCard(
                on: context,
                for: itemID,
                vaultID: vaultID,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                cardHolder: paymentCardContent.cardHolder,
                cardNumber: paymentCardContent.cardNumber,
                expirationDate: paymentCardContent.expirationDate,
                securityCode: paymentCardContent.securityCode,
                notes: paymentCardContent.notes,
                cardNumberMask: paymentCardContent.cardNumberMask,
                cardIssuer: paymentCardContent.cardIssuer
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    @nonobjc static func createPaymentCard(
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
        let entity = NSEntityDescription.insertNewObject(forEntityName: paymentCardEntityName, into: context) as! PaymentCardEntity

        entity.itemID = itemID
        entity.vaultID = vaultID
        entity.name = name
        entity.creationDate = creationDate
        entity.modificationDate = modificationDate
        entity.contentType = ItemContentType.paymentCard.rawValue
        entity.contentVersion = Int16(PaymentCardContent.contentVersion)

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

    @nonobjc static func updatePaymentCard(
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
        guard let entity = getPaymentCardEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find payment card entity for itemID: \(itemID)", module: .storage)
            return
        }

        updatePaymentCard(
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

    @nonobjc static func updatePaymentCard(
        on context: NSManagedObjectContext,
        entity: PaymentCardEntity,
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

    @nonobjc static func getPaymentCardEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> PaymentCardEntity? {
        let fetchRequest: NSFetchRequest<PaymentCardEntity> = PaymentCardEntity.fetchRequest()

        if checkInTrash {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        } else {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@ AND isTrashed == false", itemID as CVarArg)
        }

        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            Log("Error fetching PaymentCardEntity: \(error)", module: .storage)
            return nil
        }
    }

    @nonobjc static func listPaymentCardEntities(
        on context: NSManagedObjectContext,
        options: ItemsListOptions
    ) -> [PaymentCardEntity] {
        let fetchRequest: NSFetchRequest<PaymentCardEntity> = PaymentCardEntity.fetchRequest()
        fetchRequest.predicate = options.predicate
        fetchRequest.sortDescriptors = options.sortDescriptors

        do {
            return try context.fetch(fetchRequest)
        } catch {
            Log("Error fetching PaymentCardEntities: \(error)", module: .storage)
            return []
        }
    }

    override func toData() -> ItemData {
        let metadata = toMetadata()

        let content = PaymentCardContent(
            name: name,
            cardHolder: cardHolder,
            cardIssuer: cardIssuer,
            cardNumber: cardNumber,
            cardNumberMask: cardNumberMask,
            expirationDate: expirationDate,
            securityCode: securityCode,
            notes: notes
        )

        return .paymentCard(PaymentCardItemData(
            id: itemID,
            vaultId: vaultID,
            metadata: metadata,
            name: name,
            content: content
        ))
    }
}
