// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol SyncInteracting: AnyObject {
    func syncAndApplyChanges(from external: [PasswordData], externalTags: [ItemTagData], externalDeleted: [DeletedItemData])
}

final class SyncInteractor {
    private var addedPasswords: [PasswordData] = []
    private var modifiedPasswords: [PasswordData] = []
    private var deletedPasswords: [PasswordData] = [] // moved to trash
    
    private var addedTags: [ItemTagData] = []
    private var modifiedTags: [ItemTagData] = []
    private var deletedTags: [ItemTagData] = []
    
    private var addedDeleted: [DeletedItemData] = []
    private var modifiedDeleted: [DeletedItemData] = []
    private var removedDeleted: [DeletedItemData] = []
    
    private let passwordInteractor: PasswordInteracting
    private let passwordImportInteractor: PasswordImportInteracting
    private let autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    
    init(passwordInteractor: PasswordInteracting, passwordImportInteractor: PasswordImportInteracting, autoFillCredentialsInteractor: AutoFillCredentialsInteracting) {
        self.passwordInteractor = passwordInteractor
        self.passwordImportInteractor = passwordImportInteractor
        self.autoFillCredentialsInteractor = autoFillCredentialsInteractor
    }
}

extension SyncInteractor: SyncInteracting {
    func syncAndApplyChanges(from external: [PasswordData], externalTags: [ItemTagData], externalDeleted: [DeletedItemData]) {
        let local = passwordInteractor.listAllPasswords()
        let localTags = passwordInteractor.listAllTags()
        let localDeleted = passwordInteractor.listDeletedItems()
        
        sync(local: local, external: external, localTags: localTags, externalTags: externalTags, localDeleted: localDeleted, externalDeleted: externalDeleted)
        
        addedPasswords.forEach { pass in
            _ = passwordInteractor.createPassword(
                passwordID: pass.passwordID,
                name: pass.name,
                username: pass.username,
                password: decrypt(pass.password, protectionLevel: pass.protectionLevel),
                notes: pass.notes?.sanitizeNotes(),
                creationDate: pass.creationDate,
                modificationDate: pass.modificationDate,
                iconType: pass.iconType,
                trashedStatus: pass.trashedStatus,
                protectionLevel: pass.protectionLevel,
                uris: pass.uris,
                tagIds: pass.tagIds
            )
        }
        
        modifiedPasswords.forEach { pass in
            _ = passwordInteractor.updatePassword(
                for: pass.passwordID,
                name: pass.name,
                username: pass.username,
                password: decrypt(pass.password, protectionLevel: pass.protectionLevel),
                notes: pass.notes?.sanitizeNotes(),
                modificationDate: pass.modificationDate,
                iconType: pass.iconType,
                trashedStatus: pass.trashedStatus,
                protectionLevel: pass.protectionLevel,
                uris: pass.uris,
                tagIds: pass.tagIds
            )
        }
        
        deletedPasswords.forEach { pass in
            passwordInteractor.externalMarkAsTrashed(for: pass.passwordID)
        }
        
        addedTags.forEach({
            passwordInteractor.createTag(data: $0)
        })
        
        modifiedTags.forEach({
            passwordInteractor.updateTag(data: $0)
        })
                             
        deletedTags.forEach({
            passwordInteractor.externalDeleteTag(tagID: $0.tagID)
        })
        
        addedDeleted.forEach({
            passwordInteractor.createDeletedItem(id: $0.itemID, kind: $0.kind, deletedAt: $0.deletedAt)
        })
        
        modifiedDeleted.forEach({
            passwordInteractor.updateDeletedItem(id: $0.itemID, kind: $0.kind, deletedAt: $0.deletedAt)
        })
        
        removedDeleted.forEach { deleted in
            passwordInteractor.deleteDeletedItem(id: deleted.itemID)
        }
        
        Log("SyncInteractor:\nadded: \(addedPasswords.count)\nmodified: \(modifiedPasswords.count)\ntrashed: \(deletedPasswords.count)\nadded deletitions: \(addedDeleted.count)\nremoved deletitions: \(removedDeleted.count)")
        
        passwordInteractor.saveStorage()
        
        if addedPasswords.isEmpty == false || modifiedPasswords.isEmpty == false || deletedPasswords.isEmpty == false {
            Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                try await autoFillCredentialsInteractor.syncSuggestions()
            }
        }
        
        clearChangeList()
    }
    
    @discardableResult
    func sync(
        local: [PasswordData],
        external: [PasswordData],
        localTags: [ItemTagData],
        externalTags: [ItemTagData],
        localDeleted: [DeletedItemData],
        externalDeleted: [DeletedItemData]
    ) -> (passwords: [PasswordData], tags: [ItemTagData], deleted: [DeletedItemData]) {
        clearChangeList()
        
        let mergedPasswords = mergePasswords(local: local, external: external)
        let mergedTags = mergeTags(local: localTags, external: externalTags)
        let mergedDeleted = mergeDeleted(localDeleted: localDeleted, externalDeleted: externalDeleted)
        let (passwords, tags, deleted) = mergePasswordsAndDeleted(mergedPasswords, tags: mergedTags, deleted: mergedDeleted)
        
        return (passwords: passwords, tags: tags, deleted: deleted)
    }
}

private extension SyncInteractor {
    func mergePasswords(local: [PasswordData], external: [PasswordData]) -> [PasswordData] {
        var result = local
        for pass in external {
            if let index = result.firstIndex(where: { $0.passwordID == pass.passwordID }), let localPass = result[safe: index] {
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
    
    func mergePasswordsAndDeleted(_ passwords: [PasswordData], tags: [ItemTagData], deleted: [DeletedItemData]) -> ([PasswordData], [ItemTagData], [DeletedItemData]) {
        var passwords = passwords
        var tags = tags
        var deletedResult: [DeletedItemData] = []
        
        for del in deleted {
            if let index = passwords.firstIndex(where: { $0.passwordID == del.itemID && !$0.isTrashed }), let pass = passwords[safe: index] {
                if pass.modificationDate < del.deletedAt {
                    passwords.remove(at: index)
                    deletedResult.append(del)
                    
                    addedPasswords.removeAll(where: { $0.id == pass.passwordID })
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
    
    func decrypt(_ data: Data?, protectionLevel: PasswordProtectionLevel) -> String? {
        guard let data else { return nil }
        return passwordInteractor.decrypt(data, isPassword: true, protectionLevel: protectionLevel)
    }
}
