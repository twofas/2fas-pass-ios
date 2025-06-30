// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import SwiftUI

struct ConnectRouter: Router {
    
    static func buildView(onScannedQRCode: @escaping Callback, onScanAgain: @escaping Callback) -> some View {
        ConnectView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.connectModuleInteractor(),
            onScannedQRCode: onScannedQRCode,
            onScanAgain: onScanAgain)
        )
    }
    
    func routingType(for destination: ConnectDestination?) -> RoutingType? {
        .sheet
    }
    
    func view(for destination: ConnectDestination) -> some View {
        switch destination {
        case .permissions(let onFinish):
            ConnectPermissionsRouter.buildView(onFinish: onFinish)
        }
    }
}
