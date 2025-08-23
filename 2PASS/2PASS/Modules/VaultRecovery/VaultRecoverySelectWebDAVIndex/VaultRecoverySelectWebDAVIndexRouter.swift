// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data
import CommonUI

struct VaultRecoverySelectWebDAVIndexRouter: Router {
    
    @ViewBuilder
    static func buildView(
        index: WebDAVIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: @escaping (ExchangeVault) -> Void,
    )
    -> some View {
        let presenter = VaultRecoverySelectWebDAVIndexPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoverySelectWebDAVIndexModuleInteractor(),
            index: index,
            baseURL: baseURL,
            allowTLSOff: allowTLSOff,
            login: login,
            password: password,
            onSelect: onSelect
        )
        
        NavigationStack {
            VaultRecoverySelectWebDAVIndexView(presenter: presenter)
        }
    }
    
    @ViewBuilder
    func view(for destination: VaultRecoverySelectWebDAVIndexDestination) -> some View {
        switch destination {
        case .error(_, let onClose):
            Button(T.commonOk.localizedKey, action: onClose)
        case .selectRecoveryKey(let vault, let onClose):
            VaultRecoverySelectRouter.buildView(flowContext: .onboarding(onClose: onClose), recoveryData: .file(vault))
        }
    }
    
    func routingType(for destination: VaultRecoverySelectWebDAVIndexDestination?) -> RoutingType? {
        switch destination {
        case .selectRecoveryKey: .push
        case .error(let message, _): .alert(title: T.commonError, message: message)
        case nil: nil
        }
    }
}
