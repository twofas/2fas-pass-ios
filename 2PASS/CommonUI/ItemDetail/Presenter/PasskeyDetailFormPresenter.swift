// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable
final class PasskeyDetailFormPresenter: ItemDetailFormPresenter {

    private(set) var passkeyItem: PasskeyItemData

    var rpID: String {
        passkeyItem.content.rpId
    }

    var username: String {
        passkeyItem.content.username
    }

    init(item: PasskeyItemData, configuration: ItemDetailFormConfiguration) {
        self.passkeyItem = item
        super.init(item: item, configuration: configuration)
    }

    func reload() {
        guard let newItem = interactor.fetchItem(for: passkeyItem.id)?.asPasskeyItem else {
            return
        }
        self.passkeyItem = newItem
    }

    // MARK: - Actions

    func onSelectUsername() {
        if #available(iOS 18.0, *), autoFillEnvironment?.isTextToInsert == true {
            flowController.autoFillTextToInsert(username)
        }
    }

    func onCopyUsername() {
        interactor.copy(username)
        toastPresenter.presentUsernameCopied()
    }

    func onCopyRpID() {
        interactor.copy(rpID)
        toastPresenter.presentCopied()
    }
}
