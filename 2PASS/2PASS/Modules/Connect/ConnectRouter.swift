// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import Data
import SwiftUI

struct ConnectRouter: Router {
    
    static func buildView(
        onClose: @escaping Callback,
        onScannedSession: @escaping (ConnectSession) -> Void
    ) -> (view: some View, presenter: ConnectPresenter) {
        let presenter = ConnectPresenter(
            interactor: ModuleInteractorFactory.shared.connectModuleInteractor(),
            cameraInteractor: ModuleInteractorFactory.shared.connectCameraModuleInteractor(),
            onScannedSession: onScannedSession
        )
        let view = ConnectView(presenter: presenter)
            .onClose(onClose)
        return (view, presenter)
    }

    func routingType(for destination: ConnectDestination?) -> RoutingType? {
        switch destination {
        case .permissions(_, let routingType):
            routingType
        case nil:
            nil
        }
    }

    func view(for destination: ConnectDestination) -> some View {
        switch destination {
        case .permissions(let onFinish, let routingType):
            ConnectPermissionsRouter.buildView(
                onFinish: onFinish,
                usesNavigationStack: routingType == .sheet
            )
        }
    }
}
