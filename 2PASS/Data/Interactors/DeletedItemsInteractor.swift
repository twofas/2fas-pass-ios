// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol DeletedItemsInteracting: AnyObject {
    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date)
    func createDeletedItems(_ items: [DeletedItemData])
    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date)
    func updateDeletedItems(_ items: [DeletedItemData])
    func listDeletedItems() -> [DeletedItemData]
    func deleteDeletedItem(id: DeletedItemID)
}

final class DeletedItemsInteractor {
    private let mainRepository: MainRepository
    private let vaultsInteractor: VaultsInteracting

    private var vaultID: VaultID {
        vaultsInteractor.defaultVaultID
    }

    init(mainRepository: MainRepository, vaultsInteractor: VaultsInteracting) {
        self.mainRepository = mainRepository
        self.vaultsInteractor = vaultsInteractor
    }
}

extension DeletedItemsInteractor: DeletedItemsInteracting {
    func createDeletedItem(id: ItemTagID, kind: DeletedItemData.Kind, deletedAt: Date) {
        let vaultID = self.vaultID
        if let existing = mainRepository.deletedItem(id: id) {
            if deletedAt > existing.deletedAt {
                mainRepository.updateDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
            }
        } else {
            mainRepository.createDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
        }
    }

    func createDeletedItems(_ items: [DeletedItemData]) {
        guard !items.isEmpty else { return }
        let vaultID = self.vaultID
        let ids = Set(items.map(\.itemID))
        let existingByID = mainRepository.listDeletedItems(ids: ids)
            .reduce(into: [DeletedItemID: DeletedItemData]()) { $0[$1.itemID] = $1 }

        for item in items {
            if let existing = existingByID[item.itemID] {
                if item.deletedAt > existing.deletedAt {
                    mainRepository.updateDeletedItem(
                        id: item.itemID, kind: item.kind, deletedAt: item.deletedAt, in: vaultID
                    )
                }
            } else {
                mainRepository.createDeletedItem(
                    id: item.itemID, kind: item.kind, deletedAt: item.deletedAt, in: vaultID
                )
            }
        }
    }

    func listDeletedItems() -> [DeletedItemData] {
        return mainRepository.listDeletedItems(in: vaultID, limit: nil)
    }
    
    func deleteDeletedItem(id: ItemID) {
        mainRepository.deleteDeletedItem(id: id)
    }
    
    func updateDeletedItem(id: ItemID, kind: DeletedItemData.Kind, deletedAt: Date) {
        mainRepository.updateDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }

    func updateDeletedItems(_ items: [DeletedItemData]) {
        guard !items.isEmpty else { return }
        mainRepository.updateDeletedItems(items)
    }
}
