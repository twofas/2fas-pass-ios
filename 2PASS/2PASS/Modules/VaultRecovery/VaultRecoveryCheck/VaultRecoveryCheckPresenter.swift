// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common

enum VaultRecoveryCheckDestination: Identifiable {
    var id: String {
        switch self {
        case .encrypted: "encrypted"
        }
    }
    
    case encrypted(fileData: ExchangeVaultVersioned)
}

@Observable
final class VaultRecoveryCheckPresenter {
    enum State {
        case checking
        case decrypted
        case error(String)
    }
    
    private let interactor: VaultRecoveryCheckModuleInteracting
    
    var state: State = .checking
    let onClose: Callback
    
    var destination: VaultRecoveryCheckDestination?
    
    init(
        interactor: VaultRecoveryCheckModuleInteracting,
        onClose: @escaping Callback
    ) {
        self.interactor = interactor
        self.onClose = onClose
    }
}

extension VaultRecoveryCheckPresenter {
    func onAppear() {
        interactor.openFile { [weak self] result in
            switch result {
            case .success(let data):
                self?.interactor.parseContents(of: data, completion: { [weak self] parseResult in
                    guard let self else { return }
                    switch parseResult {
                    case .success(let result):
                        switch result {
                        case .decrypted:
                            state = .decrypted
                            
                        case .needsPassword(let vault, _, _, _, _):
                            destination = .encrypted(fileData: vault)
                        }
                    case .failure(let error):
                        state = .error(error.localizedDescription)
                    }
                })
            case .failure(let error):
                self?.state = .error(error.localizedDescription)
            }
        }
    }
}
