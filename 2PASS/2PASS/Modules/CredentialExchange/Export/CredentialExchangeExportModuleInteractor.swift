// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data
import AuthenticationServices

@available(iOS 26.0, *)
protocol CredentialExchangeExportModuleInteracting: AnyObject {
    @MainActor func performExport(anchor: ASPresentationAnchor) async throws
}

@available(iOS 26.0, *)
final class CredentialExchangeExportModuleInteractor: CredentialExchangeExportModuleInteracting {

    private let exporter: CredentialExchangeExporting
    private let itemsInteractor: ItemsInteracting

    init(
        exporter: CredentialExchangeExporting,
        itemsInteractor: ItemsInteracting
    ) {
        self.exporter = exporter
        self.itemsInteractor = itemsInteractor
    }

    @MainActor
    func performExport(anchor: ASPresentationAnchor) async throws {
        let items = itemsInteractor.listItems(
            searchPhrase: nil,
            tagId: nil,
            vaultId: nil,
            contentTypes: nil,
            protectionLevel: nil,
            sortBy: .newestFirst,
            trashed: .no
        )

        let manager = ASCredentialExportManager(presentationAnchor: anchor)
        _ = try await manager.requestExport()

        let exportData = exporter.convert(items)

        try await manager.exportCredentials(exportData)
    }
}
