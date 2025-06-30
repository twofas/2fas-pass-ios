// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct ConnectIntroRouter: Router {
    
    func routingType(for destination: ConnectIntroDestination?) -> RoutingType? {
        switch destination {
        case .permissions:
            return .sheet
        case nil:
            return nil
        }
    }
    
    @ViewBuilder
    func view(for destination: ConnectIntroDestination) -> some View {
        switch destination {
        case .permissions(let onFinish):
            ConnectPermissionsRouter.buildView(onFinish: onFinish)
        }
    }
}
