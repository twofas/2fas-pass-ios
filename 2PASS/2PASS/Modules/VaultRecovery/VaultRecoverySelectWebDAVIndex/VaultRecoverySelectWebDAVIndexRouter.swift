// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data
import Backup
import CommonUI

struct VaultRecoverySelectWebDAVIndexRouter: Router {
    
    @ViewBuilder
    static func buildView(
        index: BackupIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: @escaping (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void,
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
            Button(.commonOk, action: onClose)
        case .selectRecoveryKey(let vault, let onClose):
            // This downstream view is only reached when the recovery flow has already been
            // routed through `VaultRecoveryWebDAVPresenter`, which carries the source config
            // forward via `.select(.file(vault, source:))`. This nested router branch (kept
            // for the alternative layout it serves) loses that source — `.localFile` here
            // marks "no transport credentials to persist."
            VaultRecoverySelectRouter.buildView(flowContext: .onboarding(onClose: onClose), recoveryData: .file(vault, source: .localFile))
        case .appUpdateNeeded(_, let onUpdate, let onClose):
            Button(.importInvalidSchemaErrorCta, action: onUpdate)
            Button(.commonCancel, role: .cancel, action: onClose)
        }
    }
    
    func routingType(for destination: VaultRecoverySelectWebDAVIndexDestination?) -> RoutingType? {
        switch destination {
        case .selectRecoveryKey: .push
        case .error(let message, _): .alert(title: String(localized: .commonError), message: message)
        case .appUpdateNeeded(let schemaVersion, _, _):
            .alert(
                title: String(localized: .commonError),
                message: String(localized: .importInvalidSchemaErrorMsg(Int32(schemaVersion)))
            )
        case nil: nil
        }
    }
}
