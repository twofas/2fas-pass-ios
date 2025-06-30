// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CommonUI

final class AppStateBuilder {
    static func build() -> AppStateView {
        let presenter = AppStatePresenter(
            interactor: ModuleInteractorFactory.shared.appStateModuleInteractor()
        )
        let appState = AppStateView(presenter: presenter)
        
        return appState
    }
}
