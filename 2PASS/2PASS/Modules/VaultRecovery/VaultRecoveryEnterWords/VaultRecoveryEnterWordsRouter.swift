// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data
import CommonUI

struct VaultRecoveryEnterWordsRouter: Router {
    
    @ViewBuilder
    static func buildView(recoveryData: VaultRecoveryData, onEntropy: @escaping (Entropy) -> Void)
    -> some View {
        let presenter = VaultRecoveryEnterWordsPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryEnterWordsModuleInteractor(),
            recoveryData: recoveryData,
            onEntropy: onEntropy
        )
        
        NavigationStack {
            VaultRecoveryEnterWordsView(presenter: presenter)
        }
    }
    
    @ViewBuilder
    func view(for destination: VaultRecoveryEnterWordsDestination) -> some View {
        switch destination {
        case .incorrectWordsAlert:
            Button(T.commonOk.localizedKey) {}
        }
    }
    
    func routingType(for destination: VaultRecoveryEnterWordsDestination?) -> RoutingType? {
        switch destination {
        case .incorrectWordsAlert:
            .alert(title: T.commonError, message: T.restoreManualKeyIncorrectWords)
        default: nil
        }
    }
}
