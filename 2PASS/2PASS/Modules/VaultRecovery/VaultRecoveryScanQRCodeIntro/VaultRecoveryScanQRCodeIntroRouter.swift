// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryScanQRCodeIntroRouter: Router {

    static func buildView(flowContext: VaultRecoveryFlowContext, recoveryData: VaultRecoveryData) -> some View {
        VaultRecoveryScanQRCodeIntroView(presenter: .init(flowContext: flowContext, recoveryData: recoveryData))
    }

    func routingType(for destination: VaultRecoveryScanQRCodeIntroDestination?) -> RoutingType? {
        switch destination {
        case .camera: .push
        case nil: nil
        }
    }

    func view(for destination: VaultRecoveryScanQRCodeIntroDestination) -> some View {
        switch destination {
        case .camera(let flowContext, let recoveryData, let onTryAgain):
            VaultRecoveryCameraRouter.buildView(flowContext: flowContext, recoveryData: recoveryData, onTryAgain: onTryAgain)
        }
    }
}
