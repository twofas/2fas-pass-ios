// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CommonUI

final class EventLogBuilder {
    static func build() -> EventLogView {
        let presenter = EventLogPresenter(
            interactor: ModuleInteractorFactory.shared.eventLogModuleInteractor()
        )
        let appState = EventLogView(presenter: presenter)
        
        return appState
    }
}
