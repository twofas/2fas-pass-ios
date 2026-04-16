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
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let data = try await interactor.openFile()
                let result = try await interactor.parseContents(of: data)
                switch result {
                case .decrypted:
                    state = .decrypted
                case .needsPassword(let vault, _, _, _, _):
                    destination = .encrypted(fileData: vault)
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
