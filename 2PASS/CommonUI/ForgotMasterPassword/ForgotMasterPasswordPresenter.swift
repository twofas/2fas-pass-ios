// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

enum ForgotMasterPasswordDestination: RouterDestination {
    case placeholder

    var id: String {
        "placeholder"
    }
}

@Observable
final class ForgotMasterPasswordPresenter {

    var destination: ForgotMasterPasswordDestination?

    private let interactor: ForgotMasterPasswordModuleInteracting

    init(interactor: ForgotMasterPasswordModuleInteracting) {
        self.interactor = interactor
    }

    func onAppear() {}
}
