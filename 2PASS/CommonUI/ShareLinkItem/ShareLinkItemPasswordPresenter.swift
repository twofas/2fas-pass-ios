// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

@Observable
final class ShareLinkItemPasswordPresenter {
    let initialPassword: String
    var password: String
    var showGeneratePassword: Bool = false

    private let interactor: ShareLinkItemModuleInteracting

    init(initialPassword: String, interactor: ShareLinkItemModuleInteracting) {
        self.initialPassword = initialPassword
        self.password = initialPassword
        self.interactor = interactor
    }

    func randomPassword() {
        password = interactor.generatePassword()
    }
}
