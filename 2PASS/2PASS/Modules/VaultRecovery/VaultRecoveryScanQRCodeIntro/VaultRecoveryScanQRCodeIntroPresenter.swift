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
    case camera(onScanned: (Entropy, MasterKey?) -> Void)

    var id: String {
        switch self {
        case .camera: "camera"
        }
    }
}

@Observable
final class VaultRecoveryScanQRCodeIntroPresenter {
    
    var destination: VaultRecoveryScanQRCodeIntroDestination?
    
    private let onScanned: (Entropy, MasterKey?) -> Void
    
    init(onScanned: @escaping (Entropy, MasterKey?) -> Void) {
        self.onScanned = onScanned
    }
    
    func onContinue() {
        destination = .camera(onScanned: onScanned)
    }
}
