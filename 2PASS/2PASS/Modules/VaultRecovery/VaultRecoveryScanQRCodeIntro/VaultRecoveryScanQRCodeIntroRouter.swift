// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Data

struct VaultRecoveryScanQRCodeIntroRouter: Router {

    static func buildView(onScanned: @escaping (Entropy, MasterKey?) -> Void) -> some View {
        NavigationStack {
            VaultRecoveryScanQRCodeIntroView(presenter: .init(onScanned: onScanned))
        }
    }

    func routingType(for destination: VaultRecoveryScanQRCodeIntroDestination?) -> RoutingType? {
        switch destination {
        case .camera: .push
        case nil: nil
        }
    }

    func view(for destination: VaultRecoveryScanQRCodeIntroDestination) -> some View {
        switch destination {
        case .camera(let onScanned):
            VaultRecoveryCameraRouter.buildView(onScanned: onScanned)
        }
    }
}
