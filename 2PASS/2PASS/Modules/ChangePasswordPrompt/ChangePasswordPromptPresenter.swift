// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable
final class ChangePasswordPromptPresenter {

    var destination: ChangePasswordPromptDestination?

    private let interactor: ChangePasswordPromptModuleInteracting
    private let onClose: Callback

    init(interactor: ChangePasswordPromptModuleInteracting, onClose: @escaping Callback) {
        self.interactor = interactor
        self.onClose = onClose
    }

    func onChangePassword() {
        interactor.finish()

        guard interactor.prepareEncryptionDataForPasswordChange() else {
            onClose()
            return
        }

        destination = .changeMasterPassword(
            onFinish: { [weak self] in
                self?.finishChangeFlow()
            },
            onClose: { [weak self] in
                self?.finishChangeFlow()
            }
        )
    }

    func onCancel() {
        interactor.finish()
        onClose()
    }

    private func finishChangeFlow() {
        interactor.clearEncryptionData()
        onClose()
    }
}
