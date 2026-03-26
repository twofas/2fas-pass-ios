// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable
final class PasskeyEditorFormPresenter: ItemEditorFormPresenter {

    var rpID: String {
        passkeyItem?.content.rpId ?? ""
    }

    var username: String {
        passkeyItem?.content.username ?? ""
    }

    private var passkeyItem: PasskeyItemData? {
        initialData as? PasskeyItemData
    }

    init(
        interactor: ItemEditorModuleInteracting,
        flowController: ItemEditorFlowControlling,
        initialData: PasskeyItemData? = nil
    ) {
        super.init(
            interactor: interactor,
            flowController: flowController,
            initialData: initialData
        )
    }

    func onSave() -> SaveItemResult {
        interactor.savePasskey(
            name: name,
            protectionLevel: protectionLevel,
            tagIds: Array(selectedTags.map { $0.tagID })
        )
    }
}
