// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct VaultRecoveryCameraRouter: Router {
    
    @ViewBuilder
    static func buildView(recoveryData: VaultRecoveryData, onCompletion: @escaping VaultRecoveryCameraCompletion)
    -> some View {
        let presenter = VaultRecoveryCameraPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryCameraModuleInteractor(),
            onCompletion: onCompletion
        )
        VaultRecoveryCameraView(presenter: presenter)
    }
    
    @ViewBuilder
    func view(for destination: VaultRecoveryCameraDestination) -> some View {
        switch destination {
        case .cameraQRCodeError(let onClose):
            Button(.commonOk, action: onClose)
        }
    }
    
    func routingType(for destination: VaultRecoveryCameraDestination?) -> RoutingType? {
        switch destination {
        case .cameraQRCodeError: .alert(title: String(localized: .commonError), message: String(localized: .cameraQrCodeError))
        case nil: nil
        }
    }
}
