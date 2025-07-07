// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol PasswordImportInteracting: AnyObject {
    func importPasswords(_ passwords: [PasswordData], tags: [ItemTagData], completion: @escaping (Int) -> Void)
    func importDeleted(_ deleted: [DeletedItemData])
}

final class PasswordImportInteractor {
    private let fileIconInteractor: FileIconInteracting
    private let passwordInteractor: PasswordInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let tagInteractor: TagInteracting
    private let mainRepository: MainRepository
    
    init(
        fileIconInteractor: FileIconInteracting,
        passwordInteractor: PasswordInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting,
        tagInteractor: TagInteracting,
        mainRepository: MainRepository
    ) {
        self.fileIconInteractor = fileIconInteractor
        self.passwordInteractor = passwordInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
        self.tagInteractor = tagInteractor
        self.mainRepository = mainRepository
    }
}

extension PasswordImportInteractor: PasswordImportInteracting {
    func importPasswords(_ passwords: [PasswordData], tags: [ItemTagData], completion: @escaping (Int) -> Void) {
        let imported = importAllPasswords(passwords, tags: tags)
        completion(imported)
    }
    
    func importDeleted(_ deleted: [DeletedItemData]) {
        let current = Set(deletedItemsInteractor.listDeletedItems())
        let toAdd = Set(deleted).subtracting(current)
        toAdd.forEach {
            deletedItemsInteractor.createDeletedItem(id: $0.itemID, kind: $0.kind, deletedAt: $0.deletedAt)
        }
        Log("PasswordImportInteractor - deleted passwords to add: \(toAdd.count)", module: .interactor)
        passwordInteractor.saveStorage()
    }
}

private extension PasswordImportInteractor {

    func importAllPasswords(_ passwords: [PasswordData], tags: [ItemTagData]) -> Int {
        Log("PasswordImportInteractor - passwords: \(passwords.count)", module: .interactor)
        var imported = 0
        var exists = 0
        var new = 0
        var failure = 0
        
        let localTags = tagInteractor.listAllTags()
        let localPasswords = passwordInteractor.listAllPasswords()
        
        let decryptedLocalPasswordValues: [PasswordID: String] = localPasswords.reduce(into: [:]) { result, password in
            if let passwordValueEnc = password.password, let passwordValue = passwordInteractor.decrypt(passwordValueEnc, isPassword: true, protectionLevel: password.protectionLevel) {
                result[password.passwordID] = passwordValue
            }
        }
        let decryptedImportingPasswordValues: [PasswordID: String] = passwords.reduce(into: [:]) { result, password in
            if let passwordValueEnc = password.password, let passwordValue = passwordInteractor.decrypt(passwordValueEnc, isPassword: true, protectionLevel: password.protectionLevel) {
                result[password.passwordID] = passwordValue
            }
        }
        
        let localPasswordByIds: [PasswordID: PasswordData] = localPasswords.reduce(into: [:]) { result, password in
            result[password.passwordID] = password
        }
        
        let localPasswordByEqualContent: [PasswordContentEqualItem: PasswordID] = localPasswords.reduce(into: [:]) { result, password in
            let localContentItem = PasswordContentEqualItem(
                name: password.name,
                username: password.username,
                password: decryptedLocalPasswordValues[password.passwordID],
                uris: password.uris
            )
            result[localContentItem] = password.passwordID
        }
        
        for tag in tags {
            if localTags.contains(where: { $0.id == tag.id }) {
                tagInteractor.updateTag(data: tag)
            } else {
                tagInteractor.createTag(data: tag)
            }
        }
        
        for password in passwords {
            func findByContent() -> PasswordData? {
                let content = PasswordContentEqualItem(
                    name: password.name,
                    username: password.username,
                    password: decryptedImportingPasswordValues[password.id],
                    uris: password.uris
                )
                
                guard let localId = localPasswordByEqualContent[content] else {
                    return nil
                }
                
                return localPasswordByIds[localId]
            }
            
            let current = localPasswordByIds[password.passwordID] ?? findByContent()
         
            if let current {
                exists += 1
                if current.modificationDate >= password.modificationDate {
                    imported += 1
                    switch current.trashedStatus {
                    case .no: break
                    case .yes: passwordInteractor.markAsNotTrashed(for: current.passwordID)
                    }
                } else {
                    switch passwordInteractor.updatePassword(
                        for: current.passwordID,
                        name: password.name,
                        username: password.username,
                        password: decryptedImportingPasswordValues[password.id],
                        notes: password.notes?.sanitizeNotes(),
                        modificationDate: password.modificationDate,
                        iconType: password.iconType,
                        trashedStatus: .no,
                        protectionLevel: password.protectionLevel,
                        uris: password.uris,
                        tagIds: password.tagIds
                    ) {
                    case .success: imported += 1
                    case .failure: failure += 1; break
                    }
                }
            } else {
                switch passwordInteractor.createPassword(
                    passwordID: password.passwordID,
                    name: password.name,
                    username: password.username,
                    password: decryptedImportingPasswordValues[password.id],
                    notes: password.notes?.sanitizeNotes(),
                    creationDate: adjustDateIfNeeded(password.creationDate),
                    modificationDate: adjustDateIfNeeded(password.modificationDate),
                    iconType: password.iconType,
                    trashedStatus: .no,
                    protectionLevel: password.protectionLevel,
                    uris: password.uris,
                    tagIds: password.tagIds
                ) {
                case .success: imported += 1; new += 1
                case .failure: failure += 1; break
                }
            }
            Log("PasswordImportInteractor - imported: \(imported), new: \(new), exists: \(exists), failure: \(failure)", module: .interactor)
        }
        Log("PasswordImportInteractor - imported: \(imported), new: \(new), exists: \(exists), failure: \(failure)", module: .interactor)
        passwordInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
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
