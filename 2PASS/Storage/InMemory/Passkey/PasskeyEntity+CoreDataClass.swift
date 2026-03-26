// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(PasskeyEntity)
final class PasskeyEntity: ItemMetadataEntity {
    @nonobjc static let passkeyEntityName = "PasskeyEntity"

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
            let passkeyContent = try decoder.decode(PasskeyItemContent.self, from: content)

            createPasskey(
                on: context,
                itemID: itemID,
                vaultID: vaultID,
                creationDate: creationDate,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                credentialID: passkeyContent.credentialId,
                rpID: passkeyContent.rpId,
                username: passkeyContent.username,
                userHandle: passkeyContent.userHandle,
                privateKey: passkeyContent.privateKey,
            )
        } catch {
            assertionFailure(error.localizedDescription)
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
            let passkeyContent = try decoder.decode(PasskeyItemContent.self, from: content)

            updatePasskey(
                on: context,
                for: itemID,
                vaultID: vaultID,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                tagIds: tagIds,
                name: name,
                credentialID: passkeyContent.credentialId,
                rpID: passkeyContent.rpId,
                username: passkeyContent.username,
                userHandle: passkeyContent.userHandle,
                privateKey: passkeyContent.privateKey
            )
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    @nonobjc static func createPasskey(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        credentialID: Data,
        rpID: String,
        username: String,
        userHandle: Data,
        privateKey: Data
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: passkeyEntityName, into: context) as! PasskeyEntity

        entity.itemID = itemID
        entity.vaultID = vaultID
        entity.name = name
        entity.creationDate = creationDate
        entity.modificationDate = modificationDate
        entity.contentType = ItemContentType.passkey.rawValue
        entity.contentVersion = Int16(PasskeyItemContent.contentVersion)

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

        entity.credentialID = credentialID
        entity.rpID = rpID
        entity.username = username
        entity.userHandle = userHandle
        entity.privateKey = privateKey
    }

    @nonobjc static func updatePasskey(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        credentialID: Data,
        rpID: String,
        username: String,
        userHandle: Data,
        privateKey: Data
    ) {
        guard let entity = getPasskeyEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find passkey entity for itemID: \(itemID)", module: .storage)
            return
        }

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

        entity.credentialID = credentialID
        entity.rpID = rpID
        entity.username = username
        entity.userHandle = userHandle
        entity.privateKey = privateKey
    }

    @nonobjc static func getPasskeyEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> PasskeyEntity? {
        let fetchRequest: NSFetchRequest<PasskeyEntity> = PasskeyEntity.fetchRequest()

        if checkInTrash {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        } else {
            fetchRequest.predicate = NSPredicate(format: "itemID == %@ AND isTrashed == false", itemID as CVarArg)
        }

        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            Log("Error fetching PasskeyEntity: \(error)", module: .storage)
            return nil
        }
    }

    @nonobjc static func listPasskeyEntities(
        on context: NSManagedObjectContext,
        options: ItemsListOptions
    ) -> [PasskeyEntity] {
        let fetchRequest: NSFetchRequest<PasskeyEntity> = PasskeyEntity.fetchRequest()
        fetchRequest.predicate = options.predicate
        fetchRequest.sortDescriptors = options.sortDescriptors

        do {
            return try context.fetch(fetchRequest)
        } catch {
            Log("Error fetching PasskeyEntities: \(error)", module: .storage)
            return []
        }
    }

    override func toData() -> ItemData {
        let metadata = toMetadata()

        let content = PasskeyItemContent(
            name: name,
            credentialId: credentialID,
            rpId: rpID,
            username: username ?? "",
            userHandle: userHandle,
            privateKey: privateKey
        )

        return .passkey(PasskeyItemData(
            id: itemID,
            vaultId: vaultID,
            metadata: metadata,
            name: name,
            content: content
        ))
    }
}
