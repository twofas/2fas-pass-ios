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
    private let importInteractor: ImportInteracting
    private let targetVaultID: VaultID

    let service: ExternalService
    let result: ExternalServiceImportResult

    init(
        service: ExternalService,
        result: ExternalServiceImportResult,
        targetVaultID: VaultID,
        itemsImportInteractor: ItemsImportInteracting,
        importInteractor: ImportInteracting
    ) {
        self.service = service
        self.result = result
        self.targetVaultID = targetVaultID
        self.itemsImportInteractor = itemsImportInteractor
        self.importInteractor = importInteractor
    }

    @MainActor
    func importItems() async {
        let readyItems: [ItemData] = result.items.compactMap {
            importInteractor.encryptItem($0, forVault: targetVaultID)
        }
        let readyTags = result.tags.map {
            importInteractor.rebindTag($0, forVault: targetVaultID)
        }
        await withCheckedContinuation { continuation in
            itemsImportInteractor.importItems(readyItems, tags: readyTags) { _ in
                continuation.resume()
            }
        }
    }
}
