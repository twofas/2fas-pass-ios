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
    private var addedPasswords: [ItemData] = []
    private var modifiedPasswords: [ItemData] = []
    private var deletedPasswords: [ItemData] = [] // moved to trash
    
    private var addedTags: [ItemTagData] = []
    private var modifiedTags: [ItemTagData] = []
    private var deletedTags: [ItemTagData] = []
    
    private var addedDeleted: [DeletedItemData] = []
    private var modifiedDeleted: [DeletedItemData] = []
    private var removedDeleted: [DeletedItemData] = []
    
    private let itemsInteractor: ItemsInteracting
    private let passwordImportInteractor: PasswordImportInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let tagInteractor: TagInteracting
    private let autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    
    init(
        itemsInteractor: ItemsInteracting,
        passwordImportInteractor: PasswordImportInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        tagInteractor: TagInteracting,
        autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.passwordImportInteractor = passwordImportInteractor
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
        
        addedPasswords.forEach { item in
            try? itemsInteractor.createItem(item)
        }
        
        modifiedPasswords.forEach { item in
            try? itemsInteractor.updateItem(item)
        }
        
        deletedPasswords.forEach { pass in
            itemsInteractor.externalMarkAsTrashed(for: pass.id)
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
        
        Log("SyncInteractor:\nadded: \(addedPasswords.count)\nmodified: \(modifiedPasswords.count)\ntrashed: \(deletedPasswords.count)\nadded deletitions: \(addedDeleted.count)\nremoved deletitions: \(removedDeleted.count)")
        
        itemsInteractor.saveStorage()
        
        if addedPasswords.isEmpty == false || modifiedPasswords.isEmpty == false || deletedPasswords.isEmpty == false {
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
    ) -> (passwords: [ItemData], tags: [ItemTagData], deleted: [DeletedItemData]) {
        clearChangeList()
        
        let mergedPasswords = mergePasswords(local: local, external: external)
        let mergedTags = mergeTags(local: localTags, external: externalTags)
        let mergedDeleted = mergeDeleted(localDeleted: localDeleted, externalDeleted: externalDeleted)
        let (passwords, tags, deleted) = mergePasswordsAndDeleted(mergedPasswords, tags: mergedTags, deleted: mergedDeleted)
        
        return (passwords: passwords, tags: tags, deleted: deleted)
    }
}

private extension SyncInteractor {
    func mergePasswords(local: [ItemData], external: [ItemData]) -> [ItemData] {
        var result = local
        for pass in external {
            if let index = result.firstIndex(where: { $0.id == pass.id }), let localPass = result[safe: index] {
                if pass != localPass && pass.modificationDate > localPass.modificationDate {
                    result[index] = pass
                    modifiedPasswords.append(pass)
                }
            } else {
                result.append(pass)
                addedPasswords.append(pass)
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
    
    func mergePasswordsAndDeleted(_ passwords: [ItemData], tags: [ItemTagData], deleted: [DeletedItemData]) -> ([ItemData], [ItemTagData], [DeletedItemData]) {
        var passwords = passwords
        var tags = tags
        var deletedResult: [DeletedItemData] = []
        
        for del in deleted {
            if let index = passwords.firstIndex(where: { $0.id == del.itemID && !$0.isTrashed }), let pass = passwords[safe: index] {
                if pass.modificationDate < del.deletedAt {
                    passwords.remove(at: index)
                    deletedResult.append(del)
                    
                    addedPasswords.removeAll(where: { $0.id == pass.id })
                    deletedPasswords.append(pass)
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
        
        return (passwords, tags, deletedResult)
    }
    
    func clearChangeList() {
        addedPasswords = []
        modifiedPasswords = []
        deletedPasswords = []
        
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
