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

    init(itemsImportInteractor: ItemsImportInteracting) {
        self.itemsImportInteractor = itemsImportInteractor
    }

    @MainActor
    func performImport(_ result: ExternalServiceImportResult) async {
        await withCheckedContinuation { continuation in
            itemsImportInteractor.importItems(result.items, tags: result.tags) { _ in
                continuation.resume()
            }
        }
    }
}
