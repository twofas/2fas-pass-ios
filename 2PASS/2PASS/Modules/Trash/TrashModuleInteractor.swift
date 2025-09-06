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
    func delete(with passwordID: PasswordID)
    func restore(with passwordID: PasswordID)
    
    func restoreAll()
    func emptyTrash()
    
    func cachedImage(from url: URL) -> Data?
    func fetchIconImage(from url: URL) async throws -> Data
}

final class TrashModuleInteractor {
    private let passwordInteractor: PasswordInteracting
    private let fileIconInteractor: FileIconInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting
    
    init(passwordInteractor: PasswordInteracting, fileIconInteractor: FileIconInteracting, syncChangeTriggerInteractor: SyncChangeTriggerInteracting, paymentStatusInteractor: PaymentStatusInteracting) {
        self.passwordInteractor = passwordInteractor
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
        return passwordInteractor.itemsCount < limit
    }
    
    var currentPlanLimitItems: Int {
        paymentStatusInteractor.entitlements.itemsLimit ?? Int.max
    }
    
    var isTrashEmpty: Bool {
        list().isEmpty
    }
    
    func list() -> [ItemData] {
        passwordInteractor.listTrashedItems()
    }
    
    func delete(with passwordID: PasswordID) {
        Log("TrashModuleInteractor: Deleting password: \(passwordID)", module: .moduleInteractor)
        passwordInteractor.deleteItem(for: passwordID)
        passwordInteractor.saveStorage()
    }
    
    func restore(with passwordID: PasswordID) {
        Log("TrashModuleInteractor: Restoring password: \(passwordID)", module: .moduleInteractor)
        passwordInteractor.markAsNotTrashed(for: passwordID)
        passwordInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func restoreAll() {
        Log("TrashModuleInteractor: Restore all", module: .moduleInteractor)
        list().forEach { password in
            passwordInteractor.markAsNotTrashed(for: password.id)
        }
        passwordInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func emptyTrash() {
        Log("TrashModuleInteractor: Empty trash", module: .moduleInteractor)
        list().forEach { password in
            passwordInteractor.deleteItem(for: password.id)
        }
        passwordInteractor.saveStorage()
    }
    
    func cachedImage(from url: URL) -> Data? {
        fileIconInteractor.cachedImage(from: url)
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
}
