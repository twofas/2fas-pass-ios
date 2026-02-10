// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI
import Data

enum VaultRecoveryScanQRCodeIntroDestination: RouterDestination {
    case camera(flowContext: VaultRecoveryFlowContext, recoveryData: VaultRecoveryData, onTryAgain: Callback)

    var id: String {
        switch self {
        case .camera: "camera"
        }
    }
}

@Observable
final class VaultRecoveryScanQRCodeIntroPresenter {
    
    var destination: VaultRecoveryScanQRCodeIntroDestination?
    
    private let flowContext: VaultRecoveryFlowContext
    private let recoveryData: VaultRecoveryData
    
    init(flowContext: VaultRecoveryFlowContext, recoveryData: VaultRecoveryData) {
        self.flowContext = flowContext
        self.recoveryData = recoveryData
    }
    
    func onContinue() {
        destination = .camera(
            flowContext: flowContext,
            recoveryData: recoveryData,
            onTryAgain: { [weak self] in
                self?.destination = nil
            }
        )
    }
}
