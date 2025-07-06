//
//  TagInteractor.swift
//  2PASS
//
//  Created by Zbigniew Cisiński on 06/07/2025.
//  Copyright © 2025 Two Factor Authentication Service, Inc. All rights reserved.
//

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
}

final class TagInteractor {
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let mainRepository: MainRepository
    
    init(deletedItemsInteractor: DeletedItemsInteracting, mainRepository: MainRepository) {
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
        guard let nameEnc = encryptName(data.name) else {
            Log("TagInteractor: Error while preparing encrypted tag name for tag creation", module: .interactor, severity: .error)
            return
        }
        mainRepository.createTag(data)
        mainRepository.createEncryptedTag(
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
    
    func updateTag(data: ItemTagData) {
        guard let nameEnc = encryptName(data.name) else {
            Log("TagInteractor: Error while preparing encrypted tag name for tag update", module: .interactor, severity: .error)
            return
        }
        mainRepository.updateTag(data)
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
        mainRepository.deleteTag(tagID: tagID)
        mainRepository.deleteEncryptedTag(tagID: tagID)
        
        deletedItemsInteractor.createDeletedItem(id: tagID, kind: .tag, deletedAt: mainRepository.currentDate)
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
