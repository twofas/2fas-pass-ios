// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct ConnectCameraRouter: Router {
    
    func routingType(for destination: ConnectCameraDestination?) -> RoutingType? {
        switch destination {
        case .connecting: .sheet
        default: nil
        }
    }
    
    @ViewBuilder
    func view(for destination: ConnectCameraDestination) -> some View {
        switch destination {
        case .connecting(let session, let onScanAgain):
            ConnectCommunicationRouter.buildView(session: session, onScanAgain: onScanAgain)
        }
    }
}
