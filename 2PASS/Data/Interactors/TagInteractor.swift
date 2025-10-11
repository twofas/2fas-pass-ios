// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Storage

public protocol TagInteracting: AnyObject {
    func createTag(name: String, color: UIColor)
    func createTag(data: ItemTagData)
    
    func updateTag(data: ItemTagData)
    
    func deleteTag(tagID: ItemTagID)
    func externalDeleteTag(tagID: ItemTagID)
    
    func listAllTags() -> [ItemTagData]
    func getTag(for id: ItemTagID) -> ItemTagData?
    func getTags(by tagIDs: [ItemTagID]) -> [ItemTagData]
    func listTagWith(_ phrase: String) -> [ItemTagData]
    
    func batchUpdateTagsForNewEncryption(_ tags: [ItemTagData])
    
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
    func createTag(name: String, color: UIColor) {
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
                color: data.color?.hexString,
                position: data.position,
                modificationDate: data.modificationDate
            )
        )
    }
    
    func updateTag(tagID: ItemTagID, name: String, color: UIColor?) {
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
                vaultID: data.vaultID,
                name: nameEnc,
                color: data.color?.hexString,
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
                    vaultID: vaultID,
                    name: nameEnc,
                    color: tag.color?.hexString,
                    position: tag.position,
                    modificationDate: date
                )
            )
        }
        
        mainRepository.batchUpdateRencryptedTags(tags, date: date)
        mainRepository.encryptedTagBatchUpdate(encryptedTags, in: vaultID)
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
