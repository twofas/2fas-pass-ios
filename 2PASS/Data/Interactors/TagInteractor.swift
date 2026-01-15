// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Storage

public protocol TagInteracting: AnyObject {
    func suggestedNewColor() -> ItemTagColor

    func createTag(name: String, color: ItemTagColor)
    func createTag(data: ItemTagData)

    func updateTag(data: ItemTagData)

    func deleteTag(tagID: ItemTagID)
    func externalDeleteTag(tagID: ItemTagID)

    func listAllTags() -> [ItemTagData]
    func listAllEncryptedTags() -> [ItemTagEncryptedData]
    func listTags(for vaultID: VaultID) -> [ItemTagData]
    func getTag(for id: ItemTagID) -> ItemTagData?
    func getTags(by tagIDs: [ItemTagID]) -> [ItemTagData]
    func listTagWith(_ phrase: String) -> [ItemTagData]

    func batchUpdateTagsForNewEncryption(_ tags: [ItemTagData])

    func applyTagChangesToItems(
        _ itemIDs: [ItemID],
        tagsToAdd: Set<ItemTagID>,
        tagsToRemove: Set<ItemTagID>
    )

    func removeDuplicatedEncryptedTags()
    func migrateTagColors()
    func shouldMigrateColor(_ color: ItemTagColor) -> Bool

    func saveStorage()
}

final class TagInteractor {
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let mainRepository: MainRepository
    
    init(
        deletedItemsInteractor: DeletedItemsInteracting,
        mainRepository: MainRepository,
    ) {
        self.deletedItemsInteractor = deletedItemsInteractor
        self.mainRepository = mainRepository
    }
}

extension TagInteractor: TagInteracting {

    func suggestedNewColor() -> ItemTagColor {
        let allTags = listAllTags()
        var colorUsage: [ItemTagColor: Int] = [:]

        for color in ItemTagColor.allKnownCases {
            colorUsage[color] = 0
        }

        for tag in allTags {
            colorUsage[tag.color, default: 0] += 1
        }

        let minUsage = colorUsage.values.min() ?? 0
        let leastUsedColors = colorUsage.filter { $0.value == minUsage }.map { $0.key }

        return leastUsedColors.randomElement() ?? .gray
    }

    func createTag(name: String, color: ItemTagColor) {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("TagInteractor: Error while getting vaultID for tag creation", module: .interactor, severity: .error)
            return
        }
        createTag(
            data: .init(
                tagID: ItemTagID(),
                vaultID: vaultID,
                name: name,
                color: color,
                position: lastPosition,
                modificationDate: mainRepository.currentDate
            )
        )
    }
    
    func createTag(data: ItemTagData) {
        guard let selectedVault = mainRepository.selectedVault else {
            Log("TagInteractor: Create tag. No vault", module: .interactor, severity: .error)
            return
        }
        guard let nameEnc = encryptName(data.name) else {
            Log("TagInteractor: Error while preparing encrypted tag name for tag creation", module: .interactor, severity: .error)
            return
        }
        
        var data = data
        if shouldMigrateColor(data.color) {
            data.color = suggestedNewColor()
        }
        
        mainRepository.createTag(
            ItemTagData(
                tagID: data.id,
                vaultID: selectedVault.vaultID,
                name: data.name,
                color: data.color,
                position: data.position,
                modificationDate: data.modificationDate
            )
        )
        mainRepository.createEncryptedTag(
            ItemTagEncryptedData(
                tagID: data.id,
                vaultID: selectedVault.vaultID,
                name: nameEnc,
                color: data.color.rawValue,
                position: data.position,
                modificationDate: data.modificationDate
            )
        )
    }
    
    func updateTag(tagID: ItemTagID, name: String, color: ItemTagColor) {
        guard let tag = getTag(for: tagID) else {
            Log("TagInteractor: Error while finding tag for tag update", module: .interactor, severity: .error)
            return
        }
        updateTag(
            data: .init(tagID: tagID,
                        vaultID: tag.vaultID,
                        name: name,
                        color: color,
                        position: tag.position,
                        modificationDate: mainRepository.currentDate
                       )
        )
    }
    
    func updateTag(data: ItemTagData) {
        guard let selectedVault = mainRepository.selectedVault else {
            Log("TagInteractor: Update tag. No vault", module: .interactor, severity: .error)
            return
        }
        guard let nameEnc = encryptName(data.name) else {
            Log("TagInteractor: Error while preparing encrypted tag name for tag update", module: .interactor, severity: .error)
            return
        }
        
        var data = data
        if shouldMigrateColor(data.color) {
            if let oldTag = mainRepository.getTag(for: data.id) {
                if shouldMigrateColor(oldTag.color) {
                    data.color = suggestedNewColor()
                } else {
                    data.color = oldTag.color
                }
            }
        }
        
        mainRepository.updateTag(
            ItemTagData(
                tagID: data.id,
                vaultID: selectedVault.vaultID,
                name: data.name,
                color: data.color,
                position: data.position,
                modificationDate: data.modificationDate
            )
        )
        mainRepository.updateEncryptedTag(
            ItemTagEncryptedData(
                tagID: data.id,
                vaultID: selectedVault.vaultID,
                name: nameEnc,
                color: data.color.rawValue,
                position: data.position,
                modificationDate: data.modificationDate
            )
        )
    }
    
    func deleteTag(tagID: ItemTagID) {
        guard let selectedVault = mainRepository.selectedVault else {
            Log("Tag interactor: Delete tag. No vault", module: .interactor, severity: .error)
            return
        }
        
        let currentDate = mainRepository.currentDate
        
        for item in mainRepository.listItems(options: .all) {
            if let tagIds = item.tagIds, tagIds.contains(tagID) {
                let updatedTagIds = tagIds.filter { $0 != tagID }
 
                mainRepository.updateMetadataItem(
                    itemID: item.id,
                    modificationDate: item.modificationDate,
                    trashedStatus: item.trashedStatus,
                    protectionLevel: item.protectionLevel,
                    tagIds: updatedTagIds.isEmpty ? nil : updatedTagIds,
                    name: item.name,
                    contentType: item.contentType,
                    contentVersion: item.contentVersion
                )
            }
        }
    
        for item in mainRepository.listEncryptedItems(in: selectedVault.vaultID) {
            if let tagIds = item.tagIds, tagIds.contains(tagID) {
                let updatedTagIds = tagIds.filter { $0 != tagID }
                
                mainRepository.updateEncryptedItem(
                    itemID: item.itemID,
                    modificationDate: currentDate,
                    trashedStatus: item.trashedStatus,
                    protectionLevel: item.protectionLevel,
                    contentType: item.contentType,
                    contentVersion: item.contentVersion,
                    content: item.content,
                    vaultID: item.vaultID,
                    tagIds: updatedTagIds.isEmpty ? nil : updatedTagIds
                )
            }
        }
        
        mainRepository.deleteTag(tagID: tagID)
        mainRepository.deleteEncryptedTag(tagID: tagID)
        
        deletedItemsInteractor.createDeletedItem(id: tagID, kind: .tag, deletedAt: currentDate)
    }
    
    func externalDeleteTag(tagID: ItemTagID) {
        mainRepository.deleteTag(tagID: tagID)
        mainRepository.deleteEncryptedTag(tagID: tagID)
    }
    
    func listAllTags() -> [ItemTagData] {
        mainRepository.listTags(options: .all)
    }
    
    func listAllEncryptedTags() -> [ItemTagEncryptedData] {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("TagInteractor: Error while getting vaultID for listing tags", module: .interactor, severity: .error)
            return []
        }
        return mainRepository.listEncryptedTags(in: vaultID)
    }

    func listTags(for vaultID: VaultID) -> [ItemTagData] {
        mainRepository.listTags(options: .byVault(vaultID))
    }

    func getTag(for id: ItemTagID) -> ItemTagData? {
        mainRepository.listTags(options: .tag(id)).first
    }
    
    func getTags(by tagIDs: [ItemTagID]) -> [ItemTagData] {
        mainRepository.listTags(options: .tags(tagIDs))
    }
    
    func listTagWith(_ phrase: String) -> [ItemTagData] {
        mainRepository.listTags(options: .byName(phrase))
    }
    
    func batchUpdateTagsForNewEncryption(_ tags: [ItemTagData]) {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("TagInteractor: Error while getting vaultID for batch tag update", module: .interactor, severity: .error)
            return
        }
        let date = mainRepository.currentDate
        var encryptedTags: [ItemTagEncryptedData] = []

        for tag in tags {
            guard let nameEnc = encryptName(tag.name) else {
                Log("TagInteractor: Error while preparing encrypted tag name for tag update", module: .interactor, severity: .error)
                continue
            }
            encryptedTags.append(
                ItemTagEncryptedData(
                    tagID: tag.id,
                    vaultID: tag.vaultID,
                    name: nameEnc,
                    color: tag.color.rawValue,
                    position: tag.position,
                    modificationDate: date
                )
            )
        }

        mainRepository.batchUpdateRencryptedTags(tags, date: date)
        mainRepository.encryptedTagBatchUpdate(encryptedTags, in: vaultID)
    }

    func migrateTagColors() {
        let allColors = ItemTagColor.allKnownCases
        var colorIndex = 0
        
        let encryptedTags = mainRepository.listAllEncryptedTags()
        
        for encryptedTag in encryptedTags {
            guard shouldMigrateColor(ItemTagColor(rawValue: encryptedTag.color)) else { continue }
            
            let newColor = allColors[colorIndex]
            colorIndex = (colorIndex + 1) % allColors.count
            
            mainRepository.updateEncryptedTag(
                ItemTagEncryptedData(
                    tagID: encryptedTag.tagID,
                    vaultID: encryptedTag.vaultID,
                    name: encryptedTag.name,
                    color: newColor.rawValue,
                    position: encryptedTag.position,
                    modificationDate: encryptedTag.modificationDate
                )
            )
        }
    }

    func removeDuplicatedEncryptedTags() {
        let allTags = mainRepository.listAllEncryptedTags()
        var seenTagIDs: Set<ItemTagID> = []

        for tag in allTags {
            if seenTagIDs.contains(tag.tagID) {
                mainRepository.deleteEncryptedTag(tagID: tag.tagID)
            } else {
                seenTagIDs.insert(tag.tagID)
            }
        }
    }

    func shouldMigrateColor(_ color: ItemTagColor) -> Bool {
        switch color {
        case .unknown(let rawValue):
            return rawValue == nil || rawValue?.hasPrefix("#") == true
        default:
            return false
        }
    }

    func applyTagChangesToItems(
        _ itemIDs: [ItemID],
        tagsToAdd: Set<ItemTagID>,
        tagsToRemove: Set<ItemTagID>
    ) {
        guard let selectedVault = mainRepository.selectedVault else {
            Log("TagInteractor: Apply tag changes. No vault", module: .interactor, severity: .error)
            return
        }

        guard tagsToAdd.isEmpty == false || tagsToRemove.isEmpty == false else { return }

        let currentDate = mainRepository.currentDate

        // Build updates for metadata items (no content re-encoding needed)
        let updatedItems: [ItemData] = mainRepository.listItems(options: .includeItems(itemIDs)).map { item in
            var currentTagIds = Set(item.tagIds ?? [])
            currentTagIds.formUnion(tagsToAdd)
            currentTagIds.subtract(tagsToRemove)
            let updatedTagIds: [ItemTagID]? = currentTagIds.isEmpty ? nil : Array(currentTagIds)
            return item.update(modificationDate: currentDate, tagIds: updatedTagIds)
        }
        mainRepository.metadataItemsBatchUpdate(updatedItems)

        // Build updates for encrypted items
        let updatedEncryptedItems: [ItemEncryptedData] = mainRepository.listEncryptedItems(
            in: selectedVault.vaultID,
            itemIDs: itemIDs,
            excludeProtectionLevels: nil
        ).map { item in
            var currentTagIds = Set(item.tagIds ?? [])
            currentTagIds.formUnion(tagsToAdd)
            currentTagIds.subtract(tagsToRemove)
            let updatedTagIds: [ItemTagID]? = currentTagIds.isEmpty ? nil : Array(currentTagIds)

            return ItemEncryptedData(
                itemID: item.itemID,
                creationDate: item.creationDate,
                modificationDate: currentDate,
                trashedStatus: item.trashedStatus,
                protectionLevel: item.protectionLevel,
                contentType: item.contentType,
                contentVersion: item.contentVersion,
                content: item.content,
                vaultID: item.vaultID,
                tagIds: updatedTagIds
            )
        }
        mainRepository.encryptedItemsBatchUpdate(updatedEncryptedItems)
    }

    func saveStorage() {
        mainRepository.saveStorage()
        mainRepository.saveEncryptedStorage()
    }
}

private extension TagInteractor {
    var lastPosition: Int {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("TagInteractor: Error while getting vaultID for last position", module: .interactor, severity: .error)
            return 0
        }
        return mainRepository.listEncryptedTags(in: vaultID).count
    }
    
    func encryptName(_ name: String) -> Data? {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal),
              let nameData = name.data(using: .utf8),
              let nameEnc = mainRepository.encrypt(nameData, key: key) else {
            return nil
        }
        return nameEnc
    }
}
