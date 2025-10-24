// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol DeletedItemsInteracting: AnyObject {
    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date)
    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date)
    func listDeletedItems() -> [DeletedItemData]
    func deleteDeletedItem(id: DeletedItemID)
}

final class DeletedItemsInteractor {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension DeletedItemsInteractor: DeletedItemsInteracting {
    func createDeletedItem(id: ItemTagID, kind: DeletedItemData.Kind, deletedAt: Date) {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("DeletedItemsInteractor: Error while getting vaultID for Deleted Password creation", module: .interactor, severity: .error)
            return
        }
        mainRepository.createDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }
    
    func listDeletedItems() -> [DeletedItemData] {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("DeletedItemsInteractor: Error while getting vaultID for listing Deleted Password", module: .interactor, severity: .error)
            return []
        }
        return mainRepository.listDeletedItems(in: vaultID, limit: nil)
    }
    
    func deleteDeletedItem(id: ItemID) {
        mainRepository.deleteDeletedItem(id: id)
    }
    
    func updateDeletedItem(id: ItemID, kind: DeletedItemData.Kind, deletedAt: Date) {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("DeletedItemsInteractor: Error while getting vaultID for Deleted Password update", module: .interactor, severity: .error)
            return
        }
        mainRepository.updateDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }
}
