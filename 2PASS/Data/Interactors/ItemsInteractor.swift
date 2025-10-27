// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public enum ItemsInteractorSaveError: Error {
    case encryptionError
    case noVault
    case contentEncodingFailure
}

public enum ItemsInteractorReencryptError: Error {
    case encryptionError
    case noVault
}

public enum ItemsInteractorGetError: Error {
    case noPassword
    case decryptionError
    case noEntity
}

public protocol ItemsInteracting: AnyObject {
    var hasItems: Bool { get }
    var itemsCount: Int { get }

    func createItem(_ item: ItemData) throws(ItemsInteractorSaveError)
    func updateItem(_ item: ItemData) throws(ItemsInteractorSaveError)
    
    func saveStorage()
    
    func listItems(
        searchPhrase: String?,
        tagId: ItemTagID?,
        vaultId: VaultID?,
        contentTypes: [ItemContentType]?,
        sortBy: SortType,
        trashed: ItemsListOptions.TrashOptions
    ) -> [ItemData]
    func listTrashedItems() -> [ItemData]
    func listAllItems() -> [ItemData]
    
    func getPasswordEncryptedContents(
        for itemID: ItemID,
        checkInTrash: Bool
    ) -> Result<String?, ItemsInteractorGetError>
    func getItem(for item: ItemID, checkInTrash: Bool) -> ItemData?
    func listEncryptedItems() -> [ItemEncryptedData]
    func getEncryptedItemEntity(itemID: ItemID) -> ItemEncryptedData?
    func createEncryptedItem(_ item: ItemEncryptedData)
    func updateEncryptedItem(_ item: ItemEncryptedData)
    
    func deleteItem(for itemID: ItemID)
    func markAsTrashed(for itemID: ItemID)
    func externalMarkAsTrashed(for itemID: ItemID)
    func markAsNotTrashed(for itemID: ItemID)
    
    @discardableResult func loadTrustedKey() -> Bool
    
    func encrypt(_ string: String, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data?
    func encryptData(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data?
    func decrypt(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> String?
    func decryptData(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data?
    func decryptContent<T>(_ result: T.Type, from data: Data, protectionLevel: ItemProtectionLevel) -> T? where T: Decodable

    // MARK: - Change Password
    func getCompleteDecryptedList() -> ([RawItemData], [ItemTagData])
    func reencryptDecryptedList(
        _ list: [RawItemData],
        tags: [ItemTagData],
        completion: @escaping (Result<Void, ItemsInteractorReencryptError>) -> Void
    )
    
    func getItemCountForTag(tagID: ItemTagID) -> Int
}

final class ItemsInteractor {
    private let mostUsedUsernamesCount = 5
    
    private let mainRepository: MainRepository
    private let protectionInteractor: ProtectionInteracting
    private let uriInteractor: URIInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let tagInteractor: TagInteracting
    
    init(
        mainRepository: MainRepository,
        protectionInteractor: ProtectionInteracting,
        uriInteractor: URIInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        tagInteractor: TagInteracting
    ) {
        self.mainRepository = mainRepository
        self.protectionInteractor = protectionInteractor
        self.uriInteractor = uriInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.tagInteractor = tagInteractor
    }
}

extension ItemsInteractor: ItemsInteracting {

    var hasItems: Bool { !mainRepository.listItems(options: .allNotTrashed).isEmpty }

    var itemsCount: Int {
        mainRepository.listItems(options: .allNotTrashed).count
    }

    func createItem(_ item: ItemData) throws(ItemsInteractorSaveError) {
        guard let selectedVault = mainRepository.selectedVault else {
            Log("ItemsInteractor: Create item. No vault", module: .interactor, severity: .error)
            throw .noVault
        }

        guard let contentData = try? item.encodeContent(using: mainRepository.jsonEncoder) else {
            Log("ItemsInteractor - can't encode content", module: .interactor, severity: .error)
            throw .contentEncodingFailure
        }

        guard let contentDataEnc = encryptData(contentData, isSecureField: false, protectionLevel: item.protectionLevel) else {
            Log("ItemsInteractor: Create item. Encryption error", module: .interactor, severity: .error)
            return
        }

        switch item {
        case .login(let loginItem):
            mainRepository.createLoginItem(
                itemID: loginItem.id,
                vaultID: loginItem.vaultId,
                creationDate: loginItem.creationDate,
                modificationDate: loginItem.modificationDate,
                trashedStatus: loginItem.trashedStatus,
                protectionLevel: loginItem.protectionLevel,
                tagIds: loginItem.tagIds,
                name: loginItem.name,
                username: loginItem.username,
                password: loginItem.password,
                notes: loginItem.notes,
                iconType: loginItem.iconType,
                uris: loginItem.uris
            )
        case .secureNote(let secureNoteItem):
            mainRepository.createSecureNoteItem(
                itemID: secureNoteItem.id,
                vaultID: secureNoteItem.vaultId,
                creationDate: secureNoteItem.creationDate,
                modificationDate: secureNoteItem.modificationDate,
                trashedStatus: secureNoteItem.trashedStatus,
                protectionLevel: secureNoteItem.protectionLevel,
                tagIds: secureNoteItem.tagIds,
                name: secureNoteItem.name,
                text: secureNoteItem.content.text
            )
        case .raw:
            mainRepository.createItem(
                itemID: item.id,
                vaultID: item.vaultId,
                creationDate: item.creationDate,
                modificationDate: item.modificationDate,
                trashedStatus: item.trashedStatus,
                protectionLevel: item.protectionLevel,
                tagIds: item.tagIds,
                name: item.name,
                contentType: item.contentType,
                contentVersion: item.contentVersion,
                content: contentData
            )
        }

        mainRepository.createEncryptedItem(
            itemID: item.id,
            creationDate: item.creationDate,
            modificationDate: item.modificationDate,
            trashedStatus: item.trashedStatus,
            protectionLevel: item.protectionLevel,
            contentType: item.contentType,
            contentVersion: item.contentVersion,
            content: contentDataEnc,
            vaultID: selectedVault.vaultID,
            tagIds: item.tagIds
        )
    }
    
    func updateItem(_ item: ItemData) throws(ItemsInteractorSaveError) {
        guard let selectedVault = mainRepository.selectedVault else {
            Log("ItemsInteractor: Update item. No vault", module: .interactor, severity: .error)
            throw .noVault
        }

        guard let contentData = try? item.encodeContent(using: mainRepository.jsonEncoder) else {
            Log("ItemsInteractor - can't encode content", module: .interactor, severity: .error)
            throw .contentEncodingFailure
        }

        guard let contentDataEnc = encryptData(contentData, isSecureField: false, protectionLevel: item.protectionLevel) else {
            Log("ItemsInteractor: Update item. Encryption error", module: .interactor, severity: .error)
            return
        }

        switch item {
        case .login(let loginItem):
            mainRepository.updateLoginItem(
                itemID: loginItem.id,
                vaultID: loginItem.vaultId,
                modificationDate: loginItem.modificationDate,
                trashedStatus: loginItem.trashedStatus,
                protectionLevel: loginItem.protectionLevel,
                tagIds: loginItem.tagIds,
                name: loginItem.name,
                username: loginItem.username,
                password: loginItem.password,
                notes: loginItem.notes,
                iconType: loginItem.iconType,
                uris: loginItem.uris
            )
        case .secureNote(let secureNoteItem):
            mainRepository.updateSecureNoteItem(
                itemID: secureNoteItem.id,
                vaultID: secureNoteItem.vaultId,
                modificationDate: secureNoteItem.modificationDate,
                trashedStatus: secureNoteItem.trashedStatus,
                protectionLevel: secureNoteItem.protectionLevel,
                tagIds: secureNoteItem.tagIds,
                name: secureNoteItem.name,
                text: secureNoteItem.content.text
            )
        case .raw:
            mainRepository.updateItem(
                itemID: item.id,
                vaultID: item.vaultId,
                modificationDate: item.modificationDate,
                trashedStatus: item.trashedStatus,
                protectionLevel: item.protectionLevel,
                tagIds: item.tagIds,
                name: item.name,
                contentType: item.contentType,
                contentVersion: item.contentVersion,
                content: contentData
            )
        }

        mainRepository.updateEncryptedItem(
            itemID: item.id,
            modificationDate: item.modificationDate,
            trashedStatus: item.trashedStatus,
            protectionLevel: item.protectionLevel,
            contentType: item.contentType,
            contentVersion: item.contentVersion,
            content: contentDataEnc,
            vaultID: selectedVault.vaultID,
            tagIds: item.tagIds
        )
    }
    
    func saveStorage() {
        mainRepository.saveStorage()
        mainRepository.saveEncryptedStorage()
    }
    
    func listItems(
        searchPhrase: String?,
        tagId: ItemTagID? = nil,
        vaultId: VaultID? = nil,
        contentTypes: [ItemContentType]? = nil,
        sortBy: SortType = .newestFirst,
        trashed: ItemsListOptions.TrashOptions = .no
    ) -> [ItemData] {
        let searchPhrase: String? = {
            if let searchPhrase {
                if searchPhrase.isEmpty {
                    return nil
                }
                return searchPhrase
            }
            return nil
        }()

        let items = mainRepository.listItems(options: .filterByPhrase(searchPhrase, sortBy: sortBy, trashed: trashed))

        return items.filter { item in
            if let tagId {
                guard item.tagIds?.contains(tagId) ?? false else {
                    return false
                }
            }

            if let vaultId {
                guard item.vaultId == vaultId else {
                    return false
                }
            }

            if let contentTypes, !contentTypes.isEmpty {
                guard contentTypes.contains(item.contentType) else {
                    return false
                }
            }

            return true
        }
    }
    
    func listTrashedItems() -> [ItemData] {
        mainRepository.listTrashedItems()
    }
    
    func listAllItems() -> [ItemData] {
        listItems(searchPhrase: nil, vaultId: nil, contentTypes: nil, sortBy: .newestFirst, trashed: .all)
    }
    
    func getPasswordEncryptedContents(for itemID: ItemID, checkInTrash: Bool = false) -> Result<String?, ItemsInteractorGetError> {
        guard let itemData = mainRepository.getItemEntity(itemID: itemID, checkInTrash: checkInTrash),
              let loginItem = itemData.asLoginItem else {
            return .failure(.noEntity)
        }
        guard let password = loginItem.password else {
            return .failure(.noPassword)
        }
        guard let decryptedPassword = decrypt(
            password,
            isSecureField: true,
            protectionLevel: loginItem.protectionLevel
        ) else {
            return .failure(.decryptionError)
        }
        return .success(decryptedPassword)
    }
    
    func getItem(for itemID: ItemID, checkInTrash: Bool) -> ItemData? {
        guard let item = mainRepository.getItemEntity(itemID: itemID, checkInTrash: checkInTrash) else {
            return nil
        }
        return item
    }
    
    func getEncryptedItemEntity(itemID: ItemID) -> ItemEncryptedData? {
        mainRepository.getEncryptedItemEntity(itemID: itemID)
    }
    
    func listEncryptedItems() -> [ItemEncryptedData] {
        guard let selectedVault = mainRepository.selectedVault else {
            Log("ItemsInteractor: listEncryptedItems. No vault", module: .interactor, severity: .error)
            return []
        }
        return mainRepository.listEncryptedItems(in: selectedVault.vaultID)
            .filter({ $0.trashedStatus == .no })
    }
    
    func createEncryptedItem(_ item: ItemEncryptedData) {
        guard let decyptedContent = decryptData(item.content, isSecureField: false, protectionLevel: item.protectionLevel) else {
            Log("Items interactor: createEncryptedItem. Error decrypting content", module: .interactor, severity: .error)
            return
        }
        
        let name = mainRepository.extractItemName(fromContent: decyptedContent)

        try? createItem(.raw(
            .init(
                id: item.itemID,
                vaultId: item.vaultID,
                metadata: .init(
                    creationDate: item.creationDate,
                    modificationDate: item.modificationDate,
                    protectionLevel: item.protectionLevel,
                    trashedStatus: item.trashedStatus,
                    tagIds: item.tagIds
                ),
                name: name,
                contentType: item.contentType,
                contentVersion: item.contentVersion,
                content: decyptedContent
            )
        ))
    }
    
    func updateEncryptedItem(_ item: ItemEncryptedData) {
        guard let decyptedContent = decryptData(item.content, isSecureField: false, protectionLevel: item.protectionLevel) else {
            Log("Items interactor: updateEncryptedItem. Error decrypting content", module: .interactor, severity: .error)
            return
        }
        
        let name = mainRepository.extractItemName(fromContent: decyptedContent)
        
        try? updateItem(.raw(
            .init(
                id: item.itemID,
                vaultId: item.vaultID,
                metadata: .init(
                    creationDate: item.creationDate,
                    modificationDate: item.modificationDate,
                    protectionLevel: item.protectionLevel,
                    trashedStatus: item.trashedStatus,
                    tagIds: item.tagIds
                ),
                name: name,
                contentType: .login,
                contentVersion: item.contentVersion,
                content: decyptedContent
            )
        ))
    }
    
    func deleteItem(for itemID: ItemID) {
        Log(
            "ItemsInteractor: Deleting item for itemID: \(itemID)",
            module: .interactor
        )
        mainRepository.deleteItem(itemID: itemID)
        mainRepository.deleteEncryptedItem(itemID: itemID)
    }
    
    func markAsTrashed(for itemID: ItemID) {
        let date = mainRepository.currentDate
        
        Log(
            "ItemsInteractor: Marking as trashed for itemID: \(itemID)",
            module: .interactor
        )
        guard let entity = getItem(for: itemID, checkInTrash: false),
              let encryptedEntity = mainRepository.getEncryptedItemEntity(itemID: itemID)
        else {
            return
        }
        
        markAsTrashed(entity: entity, encryptedEntity: encryptedEntity, date: date)
        deletedItemsInteractor.createDeletedItem(id: itemID, kind: .login, deletedAt: date)
    }
    
    func externalMarkAsTrashed(for itemID: ItemID) {
        Log(
            "ItemsInteractor: External marking as trashed for itemID: \(itemID)",
            module: .interactor
        )
        guard let entity = getItem(for: itemID, checkInTrash: false),
              let encryptedEntity = mainRepository.getEncryptedItemEntity(itemID: itemID)
        else {
            return
        }
        
        let date = mainRepository.currentDate
        markAsTrashed(entity: entity, encryptedEntity: encryptedEntity, date: date)
    }
    
    func markAsNotTrashed(for itemID: ItemID) {
        Log(
            "ItemsInteractor: Marking as not trashed for itemID: \(itemID)",
            module: .interactor
        )
        guard let entity = getItem(for: itemID, checkInTrash: true),
              let encryptedEntity = mainRepository.getEncryptedItemEntity(itemID: itemID)
        else {
            return
        }
        
        let date = mainRepository.currentDate
        
        mainRepository.updateMetadataItem(
            itemID: itemID,
            modificationDate: date,
            trashedStatus: .no,
            protectionLevel: entity.protectionLevel,
            tagIds: entity.tagIds,
            name: entity.name,
            contentType: entity.contentType,
            contentVersion: entity.contentVersion
        )

        mainRepository.updateEncryptedItem(
            itemID: itemID,
            modificationDate: date,
            trashedStatus: .no,
            protectionLevel: encryptedEntity.protectionLevel,
            contentType: encryptedEntity.contentType,
            contentVersion: encryptedEntity.contentVersion,
            content: encryptedEntity.content,
            vaultID: encryptedEntity.vaultID,
            tagIds: encryptedEntity.tagIds
        )
        deletedItemsInteractor.deleteDeletedItem(id: itemID)
    }
    
    func encrypt(_ string: String, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data? {
        guard let data = string.data(using: .utf8) else { return nil }
        return encryptData(data, isSecureField: isSecureField, protectionLevel: protectionLevel)
    }
    
    func encryptData(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data? {
        guard let key = mainRepository.getKey(isPassword: isSecureField, protectionLevel: protectionLevel) else {
            return nil
        }
        return mainRepository.encrypt(data, key: key)
    }
    
    func decryptData(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data? {
        guard let key = mainRepository.getKey(isPassword: isSecureField, protectionLevel: protectionLevel),
              let decryptedData = mainRepository.decrypt(data, key: key) else {
            return nil
        }
        return decryptedData
    }
    
    func decrypt(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> String? {
        guard let decryptedData = decryptData(data, isSecureField: isSecureField, protectionLevel: protectionLevel) else {
            return nil
        }
        return String(data: decryptedData, encoding: .utf8)
    }
    
    func decryptContent<T>(_ result: T.Type, from data: Data, protectionLevel: ItemProtectionLevel) -> T? where T : Decodable {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: protectionLevel),
              let decryptedData = mainRepository.decrypt(data, key: key) else {
            return nil
        }
        return try? mainRepository.jsonDecoder.decode(T.self, from: decryptedData)
    }
    
    // MARK: - Change Password
    
    func getCompleteDecryptedList() -> ([RawItemData], [ItemTagData])  {
        guard let selectedVault = mainRepository.selectedVault else {
            fatalError()
        }
        
        return (
            mainRepository.listEncryptedItems(in: selectedVault.vaultID)
                .compactMap({ entity -> RawItemData? in
                    do {
                        guard let decryptedContent = decryptData(entity.content, isSecureField: false, protectionLevel: entity.protectionLevel), let contentDict = try mainRepository.jsonDecoder.decode(AnyCodable.self, from: decryptedContent).value as? [String: Any] else {
                            return nil
                        }
                        
                        var newContentDict = contentDict
                        for (key, value) in contentDict where entity.contentType.isSecureField(key: key) {
                            if let stringValue = value as? String, let dataValue = Data(base64Encoded: stringValue) {
                                guard let decrypted = decrypt(dataValue, isSecureField: true, protectionLevel: entity.protectionLevel),
                                      let decryptedData = decrypted.data(using: .utf8)?.base64EncodedString() else {
                                    return nil
                                }
                                newContentDict[key] = decryptedData
                            } else {
                                return nil
                            }
                        }
                        
                        let newContent = try mainRepository.jsonEncoder.encode(AnyCodable(newContentDict))
                        return RawItemData(
                            id: entity.id,
                            vaultId: entity.vaultID,
                            metadata: .init(
                                creationDate: entity.creationDate,
                                modificationDate: entity.modificationDate,
                                protectionLevel: entity.protectionLevel,
                                trashedStatus: entity.trashedStatus,
                                tagIds: entity.tagIds
                            ),
                            name: newContentDict[ItemContentNameKey] as? String,
                            contentType: entity.contentType,
                            contentVersion: entity.contentVersion,
                            content: newContent
                        )
                    } catch {
                        return nil
                    }
                }),
            tagInteractor.listAllTags()
        )
    }
    
    func reencryptDecryptedList(
        _ list: [RawItemData],
        tags: [ItemTagData],
        completion: @escaping (Result<Void, ItemsInteractorReencryptError>) -> Void
    ) {
        let date = mainRepository.currentDate
        Log("ItemsInteractor - Reencrypting \(list.count) items", module: .interactor)
        guard let selectedVaultID = mainRepository.selectedVault?.vaultID else {
            Log("ItemsInteractor: Update item. No vault", module: .interactor, severity: .error)
            completion(.failure(.noVault))
            return
        }
        
        enum DataFiller1: Equatable {
            case itemData(RawItemData)
            case error
        }
        
        var itemsEncryptedBuffer: [DataFiller1] = list.map({ .itemData($0) })
        
        itemsEncryptedBuffer.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { i in
                let current = buffer[i]
                
                switch current {
                case .itemData(let rawItem):
                    if let contentDict = try? mainRepository.jsonDecoder.decode(AnyCodable.self, from: rawItem.content).value as? [String: Any] {
                        var newContentDict = contentDict
                        for (key, value) in contentDict where rawItem.isSecureField(key: key) {
                            if let stringValue = value as? String, let dataValue = Data(base64Encoded: stringValue) {
                                if let decrypted = encryptData(dataValue, isSecureField: true, protectionLevel: rawItem.protectionLevel) {
                                    newContentDict[key] = decrypted.base64EncodedString()
                                } else {
                                    buffer[i] = .error
                                    return
                                }
                            }
                        }
                        
                        guard let contentData = try? mainRepository.jsonEncoder.encode(AnyCodable(newContentDict)) else {
                            buffer[i] = .error
                            return
                        }
                        
                        buffer[i] = .itemData(rawItem.updateContent(contentData, using: date))
                    }
                default: break
                }
            }
        }
        
        Log("ItemsInteractor - Secure fields encrypted", module: .interactor)
        
        let itemsEncrypted = itemsEncryptedBuffer.compactMap {
            switch $0 {
            case .itemData(let itemData): itemData
            case .error: nil
            }
        }
        
        guard itemsEncrypted.count == itemsEncryptedBuffer.count else {
            completion(.failure(.encryptionError))
            return
        }
        
        enum DataFiller2: Equatable {
            case empty
            case itemData(ItemEncryptedData)
            case error
        }
        
        var fullyEncryptedBuffer: [DataFiller2] = [DataFiller2](repeating: .empty, count: itemsEncrypted.count)
        
        fullyEncryptedBuffer.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { i in
                let current = itemsEncrypted[i]
                
                if let contentDataEnc = encryptData(current.content, isSecureField: false, protectionLevel: current.protectionLevel) {
                    buffer[i] = .itemData(
                        ItemEncryptedData(
                            itemID: current.id,
                            creationDate: current.creationDate,
                            modificationDate: current.modificationDate,
                            trashedStatus: current.trashedStatus,
                            protectionLevel: current.protectionLevel,
                            contentType: current.contentType,
                            contentVersion: current.contentVersion,
                            content: contentDataEnc,
                            vaultID: selectedVaultID,
                            tagIds: current.tagIds
                        )
                    )
                } else {
                    buffer[i] = .error
                }
            }
        }
        
        let fullyEncrypted = fullyEncryptedBuffer.compactMap {
            switch $0 {
            case .itemData(let passData): passData
            default: nil
            }
        }
        
        guard fullyEncrypted.count == fullyEncryptedBuffer.count else {
            completion(.failure(.encryptionError))
            return
        }
        
        Log("ItemsInteractor - rest of the field encrypted", module: .interactor)
        
        mainRepository.itemsBatchUpdate(itemsEncrypted)
        Log("ItemsInteractor - Items entries updated", module: .interactor)
        mainRepository.encryptedItemsBatchUpdate(fullyEncrypted)
        Log("ItemsInteractor - Items encrypted entries updated", module: .interactor)
        
        tagInteractor.batchUpdateTagsForNewEncryption(tags)
        
        saveStorage()
        
        completion(.success(()))
    }
    
    @discardableResult func loadTrustedKey() -> Bool {
        guard let trustedKey = mainRepository.trustedKeyFromVault else {
            Log("ItemsInteractor - error while loading trusted key", module: .interactor, severity: .error)
            return false
        }
                
        mainRepository.setTrustedKey(trustedKey)
        return true
    }
    
    func getItemCountForTag(tagID: ItemTagID) -> Int {
        mainRepository.listItems(options: .allNotTrashed)
            .filter {
                $0.tagIds?.contains(tagID) ?? false
            }
            .count
    }
}

private extension ItemsInteractor {
    
    func markAsTrashed(entity: ItemData, encryptedEntity: ItemEncryptedData, date: Date) {
        mainRepository.updateMetadataItem(
            itemID: entity.id,
            modificationDate: entity.modificationDate,
            trashedStatus: .yes(trashingDate: date),
            protectionLevel: entity.protectionLevel,
            tagIds: entity.tagIds,
            name: entity.name,
            contentType: entity.contentType,
            contentVersion: entity.contentVersion
        )

        mainRepository.updateEncryptedItem(
            itemID: encryptedEntity.itemID,
            modificationDate: date,
            trashedStatus: .yes(trashingDate: date),
            protectionLevel: encryptedEntity.protectionLevel,
            contentType: encryptedEntity.contentType,
            contentVersion: encryptedEntity.contentVersion,
            content: encryptedEntity.content,
            vaultID: encryptedEntity.vaultID,
            tagIds: encryptedEntity.tagIds
        )
    }
}
