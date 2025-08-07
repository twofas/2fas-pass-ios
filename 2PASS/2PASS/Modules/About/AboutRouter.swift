// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct AboutRouter: Router {
    
    @MainActor
    static func buildView() -> some View {
        AboutView(presenter: .init(interactor: ModuleInteractorFactory.shared.aboutModuleInteractor()))
    }
    
    func routingType(for destination: AboutDestination?) -> RoutingType? {
        switch destination {
        case .viewLogs:
            return .fullScreenCover
        case nil:
            return nil
        }
    }
    
    func view(for destination: AboutDestination) -> some View {
        switch destination {
        case .viewLogs:
            return ViewLogsRouter.buildView()
        }
    }
}
