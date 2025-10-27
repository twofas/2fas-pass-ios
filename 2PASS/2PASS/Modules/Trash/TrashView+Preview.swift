// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

final class PreviewTrashModuleInteractor: TrashModuleInteracting {
    
    var isTrashEmpty: Bool {
        false
    }
    
    var canRestore: Bool {
        true
    }
    
    var currentPlanLimitItems: Int {
        0
    }
    
    func list() -> [ItemData] {
        []
    }
    
    func delete(with itemID: ItemID) {}
    func restore(with itemID: ItemID) {}
    func restoreAll() {}
    func emptyTrash() {}
    
    func cachedImage(from url: URL) -> Data? {
        nil
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
}
