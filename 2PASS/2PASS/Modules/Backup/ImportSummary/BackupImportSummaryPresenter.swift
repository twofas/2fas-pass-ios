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

    enum State {
        case loading
        case ready(summary: [ItemContentType: Int], contentTypes: [ItemContentType], tagsCount: Int)
        case failure
    }

    private(set) var state: State

    var selectedVaultID: VaultID?
    let availableVaults: [VaultData]

    var hasMultipleVaults: Bool {
        availableVaults.count > 1
    }

    var destination: BackupImportSummaryDestination?

    let onClose: Callback

    private let interactor: BackupImportSummaryModuleInteracting
    private let input: BackupImportInput
    private var payload: BackupImportSummaryPayload?

    init(
        interactor: BackupImportSummaryModuleInteracting,
        input: BackupImportInput,
        onClose: @escaping Callback
    ) {
        self.interactor = interactor
        self.input = input
        self.onClose = onClose

        let vaults = interactor.listVaults()
        self.availableVaults = vaults
        let defaultVaultID = interactor.defaultVaultID
        self.selectedVaultID = defaultVaultID.flatMap { id in
            vaults.contains(where: { $0.vaultID == id }) ? id : nil
        }

        self.state = .loading
    }

    func onAppear() async {
        guard case .loading = state else { return }

        switch await interactor.extractItems(from: input) {
        case .success(let payload):
            self.payload = payload
            self.state = .ready(
                summary: Self.makeSummary(items: payload.items),
                contentTypes: Self.makeContentTypes(items: payload.items),
                tagsCount: payload.tags.count
            )
        case .failure:
            self.state = .failure
        }
    }

    func onProceed() {
        guard let payload, let selectedVaultID else { return }
        destination = .importing(
            .decrypted(payload.items, tags: payload.tags, deleted: payload.deleted),
            targetVaultID: selectedVaultID,
            onClose: onClose
        )
    }

    private static func makeSummary(items: [ItemDecryptedData]) -> [ItemContentType: Int] {
        items.reduce(into: [:]) { result, item in
            result[item.contentType, default: 0] += 1
        }
    }

    private static func makeContentTypes(items: [ItemDecryptedData]) -> [ItemContentType] {
        let summary = makeSummary(items: items)
        return ItemContentType.allKnownTypes.filter { summary[$0] != nil }
    }
}
