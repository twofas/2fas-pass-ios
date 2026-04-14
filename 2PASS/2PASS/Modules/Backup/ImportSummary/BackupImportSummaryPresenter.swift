// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import Data

enum BackupImportSummaryDestination: RouterDestination {
    case importing(BackupImportInput, targetVaultID: VaultID, onClose: Callback)

    var id: String {
        switch self {
        case .importing: "importing"
        }
    }
}

@Observable @MainActor
final class BackupImportSummaryPresenter {

    let contentTypes: [ItemContentType]
    let summary: [ItemContentType: Int]
    let tagsCount: Int

    var selectedVaultID: VaultID
    let availableVaults: [VaultData]

    var hasMultipleVaults: Bool {
        availableVaults.count > 1
    }

    var destination: BackupImportSummaryDestination?

    private let interactor: BackupImportSummaryModuleInteracting
    private let items: [ItemData]
    private let tags: [ItemTagData]
    private let deleted: [DeletedItemData]
    private let onClose: Callback

    init(
        interactor: BackupImportSummaryModuleInteracting,
        items: [ItemData],
        tags: [ItemTagData],
        deleted: [DeletedItemData],
        onClose: @escaping Callback
    ) {
        self.interactor = interactor
        self.items = items
        self.tags = tags
        self.deleted = deleted
        self.onClose = onClose

        let summary: [ItemContentType: Int] = items.reduce(into: [:]) { result, item in
            let count = result[item.contentType] ?? 0
            result[item.contentType] = count + 1
        }
        self.summary = summary
        self.contentTypes = ItemContentType.allKnownTypes.filter { summary[$0] != nil }
        self.tagsCount = tags.count

        self.availableVaults = interactor.listVaults()
        let defaultVaultID = interactor.defaultVaultID
        self.selectedVaultID = availableVaults.contains(where: { $0.vaultID == defaultVaultID })
            ? defaultVaultID
            : (availableVaults.first?.vaultID ?? defaultVaultID)
    }

    func onProceed() {
        destination = .importing(
            .decrypted(items, tags: tags, deleted: deleted),
            targetVaultID: selectedVaultID,
            onClose: onClose
        )
    }
}
