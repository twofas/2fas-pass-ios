// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct VaultRecoveryWebDAVRouter: Router {
    
    @ViewBuilder
    static func buildView()
    -> some View {
        let presenter = VaultRecoveryWebDAVPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryWebDAVModuleInteractor()
        )
        
        VaultRecoveryWebDAVView(presenter: presenter)
    }
    
    @ViewBuilder
    func view(for destination: VaultRecoveryWebDAVDestination) -> some View {
        switch destination {
        case .error(_, let onClose):
            Button(T.commonOk.localizedKey, action: onClose)
        case .selectVault(let index, let baseURL, let allowTLSOff, let login, let password, let onSelect):
            VaultRecoverySelectWebDAVIndexRouter.buildView(
                index: index,
                baseURL: baseURL,
                allowTLSOff: allowTLSOff,
                login: login,
                password: password,
                onSelect: onSelect
            )
        case .select(let data, let onClose):
            VaultRecoverySelectRouter.buildView(flowContext: .onboarding(onClose: onClose), recoveryData: data)
        }
    }
    
    func routingType(for destination: VaultRecoveryWebDAVDestination?) -> RoutingType? {
        switch destination {
        case .selectVault: .sheet
        case .select: .push
        case .error(let message, _): .alert(title: T.commonError, message: message)
        case nil: nil
        }
    }
}
