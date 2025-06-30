// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct ConnectPullReqestCommunicationRouter: Router {
    
    @MainActor
    static func buildView(appNotification: AppNotification) -> some View {
        ConnectPullReqestCommunicationView(presenter: .init(interactor: ModuleInteractorFactory.shared.connectPullReqestCommunicationModuleInteractor(appNotification: appNotification)))
    }
    
    func routingType(for destination: ConnectPullReqestCommunicationDestination?) -> RoutingType? {
        .fullScreenCover
    }
    
    func view(for destination: ConnectPullReqestCommunicationDestination) -> some View {
        switch destination {
        case .addItem(let changeRequest, let onClose):
            AddPasswordRouter.buildView(id: nil, changeRequest: changeRequest, onClose: onClose)
        case .editItem(let passwordData, let changeRequest, let onClose):
            AddPasswordRouter.buildView(id: passwordData.id, changeRequest: changeRequest, onClose: onClose)
        }
    }
}
