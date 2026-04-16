// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

@available(iOS 26.0, *)
protocol CredentialExchangePerformImportModuleInteracting: AnyObject {
    @MainActor func performImport(_ result: ExternalServiceImportResult) async
}

@available(iOS 26.0, *)
final class CredentialExchangePerformImportModuleInteractor: CredentialExchangePerformImportModuleInteracting {

    private let itemsImportInteractor: ItemsImportInteracting
    private let importInteractor: ImportInteracting
    private let vaultsInteractor: VaultsInteracting

    init(
        itemsImportInteractor: ItemsImportInteracting,
        importInteractor: ImportInteracting,
        vaultsInteractor: VaultsInteracting
    ) {
        self.itemsImportInteractor = itemsImportInteractor
        self.importInteractor = importInteractor
        self.vaultsInteractor = vaultsInteractor
    }

    @MainActor
    func performImport(_ result: ExternalServiceImportResult) async {
        let targetVaultID = vaultsInteractor.defaultVaultID
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
