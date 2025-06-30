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
    
    func list() -> [PasswordData] {
        [
            PasswordData(
                passwordID: PasswordID(),
                name: "Name",
                username: "Username",
                password: nil,
                notes: nil,
                creationDate: Date(),
                modificationDate: Date(),
                iconType: .label(labelTitle: "AB", labelColor: nil),
                trashedStatus: .yes(trashingDate: Date()),
                protectionLevel: .normal,
                uris: nil,
                tagIds: nil
            ),
            PasswordData(
                passwordID: PasswordID(),
                name: "Name",
                username: "Username",
                password: nil,
                notes: nil,
                creationDate: Date(),
                modificationDate: Date(),
                iconType: .label(labelTitle: "AB", labelColor: nil),
                trashedStatus: .yes(trashingDate: Date()),
                protectionLevel: .normal,
                uris: nil,
                tagIds: nil
            )
        ]
    }
    
    func delete(with passwordID: PasswordID) {}
    func restore(with passwordID: PasswordID) {}
    func restoreAll() {}
    func emptyTrash() {}
    
    func cachedImage(from url: URL) -> Data? {
        nil
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
}
