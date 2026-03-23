// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

enum ShareLinkItemPasswordDestination: RouterDestination {
    case passwordGenerator(onUse: (String) -> Void, onClose: () -> Void)

    var id: String {
        switch self {
        case .passwordGenerator: "passwordGenerator"
        }
    }
}

@Observable
final class ShareLinkItemPasswordPresenter {

    let initialPassword: String
    var password: String
    var destination: ShareLinkItemPasswordDestination?

    private let interactor: ShareLinkItemPasswordModuleInteracting

    init(initialPassword: String, interactor: ShareLinkItemPasswordModuleInteracting) {
        self.initialPassword = initialPassword
        self.password = initialPassword
        self.interactor = interactor
    }

    func onGeneratePasswordTapped() {
        destination = .passwordGenerator(
            onUse: { [weak self] generatedPassword in
                self?.password = generatedPassword
                self?.destination = nil
            },
            onClose: { [weak self] in
                self?.destination = nil
            }
        )
    }

    func randomPassword() {
        password = interactor.generatePassword()
    }
}
