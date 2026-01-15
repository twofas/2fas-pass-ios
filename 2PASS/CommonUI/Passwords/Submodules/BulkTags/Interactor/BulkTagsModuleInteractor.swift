// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import Common

protocol BulkTagsModuleInteracting: AnyObject {
    func listAllTags() -> [ItemTagData]
}

final class BulkTagsModuleInteractor: BulkTagsModuleInteracting {

    private let tagInteractor: TagInteracting

    init(tagInteractor: TagInteracting) {
        self.tagInteractor = tagInteractor
    }

    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
            .sorted { $0.name < $1.name }
    }
}
