// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct VaultRecoveryRouter: Router {
    @ViewBuilder
    static func buildView()
    -> some View {
        let presenter = VaultRecoveryPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryModuleInteractor()
        )
        VaultRecoveryView(presenter: presenter)
    }
    
    @ViewBuilder
    func view(for destination: VaultRecoveryDestination) -> some View {
        switch destination {
        case .restoreFromFile(let url, let onClose):
            VaultRecoveryURLLoadingRouter.buildView(url: url, onClose: onClose)
        case .restoreFromWebDAV:
            VaultRecoveryWebDAVRouter.buildView()
        case .selectiCloudVault(let onSelect):
            VaultRecoveryiCloudVaultSelectionRouter.buildView(onSelect: onSelect)
        case .restore(let recoveryData, let onClose):
            VaultRecoverySelectRouter.buildView(flowContext: .onboarding(onClose: onClose), recoveryData: recoveryData)
        case .selectFile:
            EmptyView()
        case .errorReadingFile:
            Button(T.commonOk.localizedKey) {}
        }
    }
    
    func routingType(for destination: VaultRecoveryDestination?) -> RoutingType? {
        switch destination {
        case .restore: .push
        case .selectFile(let onClose): .fileImporter(contentTypes: .vaultFiles, onClose: onClose)
        case .restoreFromFile: .push
        case .selectiCloudVault: .sheet
        case .restoreFromWebDAV: .push
        case .errorReadingFile: .alert(title: T.vaultRecoveryErrorOpenFile, message: T.vaultRecoveryErrorOpenFileAccessExplain)
        case nil: nil
        }
    }
}
