// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol SyncInteracting: AnyObject {
    func syncAndApplyChanges(from external: [ItemData], externalTags: [ItemTagData], externalDeleted: [DeletedItemData])
}

final class SyncInteractor {
    private var addedItems: [ItemData] = []
    private var modifiedItems: [ItemData] = []
    private var deletedItems: [ItemData] = [] // moved to trash
    
    private var addedTags: [ItemTagData] = []
    private var modifiedTags: [ItemTagData] = []
    private var deletedTags: [ItemTagData] = []
    
    private var addedDeleted: [DeletedItemData] = []
    private var modifiedDeleted: [DeletedItemData] = []
    private var removedDeleted: [DeletedItemData] = []
    
    private let itemsInteractor: ItemsInteracting
    private let itemsImportInteractor: ItemsImportInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let tagInteractor: TagInteracting
    private let autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    
    init(
        itemsInteractor: ItemsInteracting,
        itemsImportInteractor: ItemsImportInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        tagInteractor: TagInteracting,
        autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.itemsImportInteractor = itemsImportInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.tagInteractor = tagInteractor
        self.autoFillCredentialsInteractor = autoFillCredentialsInteractor
    }
}

extension SyncInteractor: SyncInteracting {
    func syncAndApplyChanges(from external: [ItemData], externalTags: [ItemTagData], externalDeleted: [DeletedItemData]) {
        let local = itemsInteractor.listAllItems()
        let localTags = tagInteractor.listAllTags()
        let localDeleted = deletedItemsInteractor.listDeletedItems()
        
        sync(local: local, external: external, localTags: localTags, externalTags: externalTags, localDeleted: localDeleted, externalDeleted: externalDeleted)
        
        addedItems.forEach { item in
            try? itemsInteractor.createItem(item)
        }
        
        modifiedItems.forEach { item in
            try? itemsInteractor.updateItem(item)
        }
        
        deletedItems.forEach { item in
            itemsInteractor.externalMarkAsTrashed(for: item.id)
        }
        
        addedTags.forEach({
            tagInteractor.createTag(data: $0)
        })
        
        modifiedTags.forEach({
            tagInteractor.updateTag(data: $0)
        })
                             
        deletedTags.forEach({
            tagInteractor.externalDeleteTag(tagID: $0.tagID)
        })
        
        addedDeleted.forEach({
            deletedItemsInteractor.createDeletedItem(id: $0.itemID, kind: $0.kind, deletedAt: $0.deletedAt)
        })
        
        modifiedDeleted.forEach({
            deletedItemsInteractor.updateDeletedItem(id: $0.itemID, kind: $0.kind, deletedAt: $0.deletedAt)
        })
        
        removedDeleted.forEach { deleted in
            deletedItemsInteractor.deleteDeletedItem(id: deleted.itemID)
        }
        
        Log("SyncInteractor:\nadded: \(addedItems.count)\nmodified: \(modifiedItems.count)\ntrashed: \(deletedItems.count)\nadded deletitions: \(addedDeleted.count)\nremoved deletitions: \(removedDeleted.count)")
        
        itemsInteractor.saveStorage()
        
        if addedItems.isEmpty == false || modifiedItems.isEmpty == false || deletedItems.isEmpty == false {
            Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                try await autoFillCredentialsInteractor.syncSuggestions()
            }
        }
        
        clearChangeList()
    }
    
    @discardableResult
    func sync(
        local: [ItemData],
        external: [ItemData],
        localTags: [ItemTagData],
        externalTags: [ItemTagData],
        localDeleted: [DeletedItemData],
        externalDeleted: [DeletedItemData]
    ) -> (items: [ItemData], tags: [ItemTagData], deleted: [DeletedItemData]) {
        clearChangeList()
        
        let mergedItems = mergeItems(local: local, external: external)
        let mergedTags = mergeTags(local: localTags, external: externalTags)
        let mergedDeleted = mergeDeleted(localDeleted: localDeleted, externalDeleted: externalDeleted)
        let (items, tags, deleted) = mergeItemsAndDeleted(mergedItems, tags: mergedTags, deleted: mergedDeleted)
        
        return (items: items, tags: tags, deleted: deleted)
    }
}

private extension SyncInteractor {
    func mergeItems(local: [ItemData], external: [ItemData]) -> [ItemData] {
        var result = local
        for item in external {
            if let index = result.firstIndex(where: { $0.id == item.id }), let localPass = result[safe: index] {
                if item != localPass && item.modificationDate > localPass.modificationDate {
                    result[index] = item
                    modifiedItems.append(item)
                }
            } else {
                result.append(item)
                addedItems.append(item)
            }
        }
        
        return result
    }
    
    func mergeTags(local: [ItemTagData], external: [ItemTagData]) -> [ItemTagData] {
        var result = local
        for tag in external {
            if let index = result.firstIndex(where: { $0.tagID == tag.tagID }), let localTag = result[safe: index] {
                if tag != localTag && tag.modificationDate > localTag.modificationDate {
                    result[index] = tag
                    modifiedTags.append(tag)
                }
            } else {
                result.append(tag)
                addedTags.append(tag)
            }
        }
        
        return result
    }
    
    func mergeDeleted(localDeleted: [DeletedItemData], externalDeleted: [DeletedItemData]) -> [DeletedItemData] {
        var local: [DeletedItemID: DeletedItemData] = localDeleted.reduce(into: [:]) { result, item in
            result[item.itemID] = item
        }
        
        let external: [DeletedItemID: DeletedItemData] = externalDeleted.reduce(into: [:]) { result, item in
            result[item.itemID] = item
        }
        
        var all: [DeletedItemData] = []
        
        for (key, value) in external {
            if let localValue = local[key], localValue.kind == value.kind {
                if value.deletedAt > localValue.deletedAt {
                    modifiedDeleted.append(value)
                    all.append(value)
                    local[key] = nil
                }
            } else {
                addedDeleted.append(value)
                all.append(value)
            }
        }
        
        all.append(contentsOf: local.map { $0.value })
        
        return all
    }
    
    func mergeItemsAndDeleted(_ items: [ItemData], tags: [ItemTagData], deleted: [DeletedItemData]) -> ([ItemData], [ItemTagData], [DeletedItemData]) {
        var items = items
        var tags = tags
        var deletedResult: [DeletedItemData] = []
        
        for del in deleted {
            if let index = items.firstIndex(where: { $0.id == del.itemID && !$0.isTrashed }), let item = items[safe: index] {
                if item.modificationDate < del.deletedAt {
                    items.remove(at: index)
                    deletedResult.append(del)
                    
                    addedItems.removeAll(where: { $0.id == item.id })
                    deletedItems.append(item)
                } else {
                    removedDeleted.append(del)
                }
            } else if let index = tags.firstIndex(where: { $0.tagID == del.itemID }), let tag = tags[safe: index] {
                if tag.modificationDate < del.deletedAt {
                    tags.remove(at: index)
                    deletedResult.append(del)
                    
                    addedTags.removeAll(where: { $0.tagID == tag.tagID })
                    deletedTags.append(tag)
                } else {
                    removedDeleted.append(del)
                }
            } else {
                deletedResult.append(del)
            }
        }
        
        let added = Set(addedDeleted)
        let removed = Set(removedDeleted)
        let common = added.intersection(removed)
        addedDeleted = Array(added.subtracting(common))
        removedDeleted = Array(removed.subtracting(common))
        
        return (items, tags, deletedResult)
    }
    
    func clearChangeList() {
        addedItems = []
        modifiedItems = []
        deletedItems = []
        
        addedTags = []
        modifiedTags = []
        deletedTags = []
        
        addedDeleted = []
        modifiedDeleted = []
        removedDeleted = []
    }
    
    func decrypt(_ data: Data?, protectionLevel: ItemProtectionLevel) -> String? {
        guard let data else { return nil }
        return itemsInteractor.decrypt(data, isSecureField: true, protectionLevel: protectionLevel)
    }
}
