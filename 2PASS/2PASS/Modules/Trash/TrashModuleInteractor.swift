// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol TrashModuleInteracting: AnyObject {
    var currentPlanLimitItems: Int { get }
    var canRestore: Bool { get }
    var isTrashEmpty: Bool { get }

    func list() -> [ItemData]
    func delete(with itemID: ItemID)
    func restore(with itemID: ItemID)
    
    func restoreAll()
    func emptyTrash()
    
    func cachedImage(from url: URL) -> Data?
    func fetchIconImage(from url: URL) async throws -> Data
}

final class TrashModuleInteractor {
    private let itemsInteractor: ItemsInteracting
    private let fileIconInteractor: FileIconInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting
    
    init(itemsInteractor: ItemsInteracting, fileIconInteractor: FileIconInteracting, syncChangeTriggerInteractor: SyncChangeTriggerInteracting, paymentStatusInteractor: PaymentStatusInteracting) {
        self.itemsInteractor = itemsInteractor
        self.fileIconInteractor = fileIconInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
    }
}

extension TrashModuleInteractor: TrashModuleInteracting {
    
    var canRestore: Bool {
        guard let limit = paymentStatusInteractor.entitlements.itemsLimit else {
            return true
        }
        return itemsInteractor.itemsCount < limit
    }
    
    var currentPlanLimitItems: Int {
        paymentStatusInteractor.entitlements.itemsLimit ?? Int.max
    }
    
    var isTrashEmpty: Bool {
        list().isEmpty
    }
    
    func list() -> [ItemData] {
        itemsInteractor.listTrashedItems()
    }
    
    func delete(with itemID: ItemID) {
        Log("TrashModuleInteractor: Deleting item: \(itemID)", module: .moduleInteractor)
        itemsInteractor.deleteItem(for: itemID)
        itemsInteractor.saveStorage()
    }
    
    func restore(with itemID: ItemID) {
        Log("TrashModuleInteractor: Restoring item: \(itemID)", module: .moduleInteractor)
        itemsInteractor.markAsNotTrashed(for: itemID)
        itemsInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func restoreAll() {
        Log("TrashModuleInteractor: Restore all", module: .moduleInteractor)
        list().forEach { password in
            itemsInteractor.markAsNotTrashed(for: password.id)
        }
        itemsInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func emptyTrash() {
        Log("TrashModuleInteractor: Empty trash", module: .moduleInteractor)
        list().forEach { password in
            itemsInteractor.deleteItem(for: password.id)
        }
        itemsInteractor.saveStorage()
    }
    
    func cachedImage(from url: URL) -> Data? {
        fileIconInteractor.cachedImage(from: url)
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
}
