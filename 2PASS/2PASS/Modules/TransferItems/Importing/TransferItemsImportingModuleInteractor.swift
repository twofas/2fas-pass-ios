// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol TransferItemsImportingModuleInteracting {
    func importItems() async
}

final class TransferItemsImportingModuleInteractor: TransferItemsImportingModuleInteracting {

    private let itemsImportInteractor: ItemsImportInteracting

    let service: ExternalService
    let result: ExternalServiceImportResult

    init(service: ExternalService, result: ExternalServiceImportResult, itemsImportInteractor: ItemsImportInteracting) {
        self.service = service
        self.result = result
        self.itemsImportInteractor = itemsImportInteractor
    }

    @MainActor
    func importItems() async {
        await withCheckedContinuation { continuation in
            itemsImportInteractor.importItems(result.items, tags: result.tags) { _ in
                continuation.resume()
            }
        }
    }
}
