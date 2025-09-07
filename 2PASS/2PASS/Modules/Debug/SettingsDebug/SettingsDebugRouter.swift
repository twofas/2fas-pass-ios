// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct SettingsDebugRouter: Router {
    
    @MainActor
    static func buildView() -> some View {
        SettingsDebugView(presenter: .init(interactor: ModuleInteractorFactory.shared.settingsDebugInteractor()))
    }
    
    func routingType(for destination: SettingsDebugDestination?) -> RoutingType? {
        .push
    }
    
    @ViewBuilder
    func view(for destination: SettingsDebugDestination) -> some View {
        switch destination {
        case .appState:
            AppStateRouter.buildView()
        case .eventLog:
            EventLogRouter.buildView()
        case .generateItems:
            GenerateContentRouter.buildView()
        case .modifyState:
            ModifyStateRouter.buildView()
        }
    }
}
