// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol ItemsImportInteracting: AnyObject {
    func importItems(_ items: [ItemData], tags: [ItemTagData], completion: @escaping (Int) -> Void)
    func importDeleted(_ deleted: [DeletedItemData])
}

final class ItemsImportInteractor {
    private let fileIconInteractor: FileIconInteracting
    private let itemsInteractor: ItemsInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let tagInteractor: TagInteracting
    private let mainRepository: MainRepository
    
    init(
        fileIconInteractor: FileIconInteracting,
        itemsInteractor: ItemsInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting,
        tagInteractor: TagInteracting,
        mainRepository: MainRepository
    ) {
        self.fileIconInteractor = fileIconInteractor
        self.itemsInteractor = itemsInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
        self.tagInteractor = tagInteractor
        self.mainRepository = mainRepository
    }
}

extension ItemsImportInteractor: ItemsImportInteracting {
    func importItems(_ items: [ItemData], tags: [ItemTagData], completion: @escaping (Int) -> Void) {
        let imported = importAllItems(items, tags: tags)
        completion(imported)
    }
    
    func importDeleted(_ deleted: [DeletedItemData]) {
        let current = Set(deletedItemsInteractor.listDeletedItems())
        let toAdd = Set(deleted).subtracting(current)
        toAdd.forEach {
            deletedItemsInteractor.createDeletedItem(id: $0.itemID, kind: $0.kind, deletedAt: $0.deletedAt)
        }
        Log("ItemsImportInteractor - deleted items to add: \(toAdd.count)", module: .interactor)
        itemsInteractor.saveStorage()
    }
}

private extension ItemsImportInteractor {

    func importAllItems(_ items: [ItemData], tags: [ItemTagData]) -> Int {
        Log("ItemsImportInteractor - items: \(items.count)", module: .interactor)
        var imported = 0
        var exists = 0
        var new = 0
        var failure = 0
        
        let localTags = tagInteractor.listAllTags()
        let localItems = itemsInteractor.listAllItems()
        
        let decryptedLocalPasswordValues: [ItemID: String] = localItems.reduce(into: [:]) { result, item in
            if let loginItem = item.asLoginItem,
               let passwordValueEnc = loginItem.password,
               let passwordValue = itemsInteractor.decrypt(passwordValueEnc, isSecureField: true, protectionLevel: item.protectionLevel) {
                result[item.id] = passwordValue
            }
        }
        let decryptedImportingPasswordValues: [ItemID: String] = items.reduce(into: [:]) { result, item in
            if let loginItem = item.asLoginItem,
               let passwordValueEnc = loginItem.password,
               let passwordValue = itemsInteractor.decrypt(passwordValueEnc, isSecureField: true, protectionLevel: loginItem.protectionLevel) {
                result[loginItem.id] = passwordValue
            }
        }
        
        let localItemsByIds: [ItemID: ItemData] = localItems.reduce(into: [:]) { result, item in
            result[item.id] = item
        }
        
        let localPasswordByEqualContent: [PasswordContentEqualItem: ItemID] = localItems.reduce(into: [:]) { result, item in
            if let loginItem = item.asLoginItem {
                let localContentItem = PasswordContentEqualItem(
                    name: loginItem.name,
                    username: loginItem.username,
                    password: decryptedLocalPasswordValues[loginItem.id],
                    uris: loginItem.uris
                )
                result[localContentItem] = loginItem.id
            }
        }
        
        for tag in tags {
            if localTags.contains(where: { $0.id == tag.id }) {
                tagInteractor.updateTag(data: tag)
            } else {
                tagInteractor.createTag(data: tag)
            }
        }
        
        for item in items {
            let item = item.update(
                creationDate: adjustDateIfNeeded(item.creationDate),
                modificationDate: adjustDateIfNeeded(item.modificationDate)
            )
            
            func findByContent() -> (ItemData)? {
                if let loginItem = item.asLoginItem {
                    let content = PasswordContentEqualItem(
                        name: loginItem.name,
                        username: loginItem.username,
                        password: decryptedImportingPasswordValues[loginItem.id],
                        uris: loginItem.uris
                    )
                    
                    guard let localId = localPasswordByEqualContent[content] else {
                        return nil
                    }
                    
                    return localItemsByIds[localId]
                }
                return nil
            }
            
            let current = localItemsByIds[item.id] ?? findByContent()
         
            if let current {
                exists += 1
                if current.modificationDate >= item.modificationDate {
                    imported += 1
                    switch current.trashedStatus {
                    case .no: break
                    case .yes: itemsInteractor.markAsNotTrashed(for: current.id)
                    }
                } else {
                    do {
                        try itemsInteractor.updateItem(item)
                        imported += 1
                    } catch {
                        failure += 1
                    }
                }
            } else {
                do {
                    try itemsInteractor.createItem(item)
                    imported += 1; new += 1
                } catch {
                    failure += 1
                }
            }
            Log("ItemsImportInteractor - imported: \(imported), new: \(new), exists: \(exists), failure: \(failure)", module: .interactor)
        }
        Log("PasswordImportInteractor - imported: \(imported), new: \(new), exists: \(exists), failure: \(failure)", module: .interactor)
        itemsInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()

        NotificationCenter.default.post(name: .didImportItems, object: nil)
        
        return imported
    }
    
    private func adjustDateIfNeeded(_ date: Date) -> Date {
        if date == Date.importPasswordPlaceholder {
            return mainRepository.currentDate
        } else {
            return date
        }
    }
}

extension Sequence {
    func asyncCompactMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()
        
        for element in self {
            try await values.append(transform(element))
        }
        
        return values
    }
}

private struct PasswordContentEqualItem: Hashable {
    let name: String?
    let username: String?
    let password: String?
    let uris: [PasswordURI]?
}
