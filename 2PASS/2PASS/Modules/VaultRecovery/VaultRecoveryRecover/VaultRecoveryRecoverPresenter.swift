// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

@Observable
final class VaultRecoveryRecoverPresenter {
    enum State {
        case loading
        case success
        case error
    }
    private let interactor: VaultRecoveryRecoverModuleInteracting
        
    var state: State = .loading
    
    init(interactor: VaultRecoveryRecoverModuleInteracting) {
        self.interactor = interactor
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
