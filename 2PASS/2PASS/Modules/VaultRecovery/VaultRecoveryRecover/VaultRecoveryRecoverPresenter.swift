// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

@Observable
final class VaultRecoveryRecoverPresenter {
    enum State {
        case loading
        case success
        case error
    }

    private let interactor: VaultRecoveryRecoverModuleInteracting
    private let onTryAgain: Callback

    var state: State = .loading

    init(interactor: VaultRecoveryRecoverModuleInteracting, onTryAgain: @escaping Callback) {
        self.interactor = interactor
        self.onTryAgain = onTryAgain
    }

    func handleTryAgain() {
        onTryAgain()
    }
}

extension VaultRecoveryRecoverPresenter {
    
    func onAppear() {
        interactor.recover { [weak self] success in
            guard let self else { return }
            if success {
                self.interactor.finish()
                state = .success
            } else {
                state = .error
            }
        }
    }
}
