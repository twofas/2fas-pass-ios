// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct SetupCompleteRouter {
    
    @MainActor @ViewBuilder
    static func buildView() -> some View {
        SetupCompleteView(presenter: SetupCompletePresenter(interactor: ModuleInteractorFactory.shared.setupCompleteModuleInteractor()))
    }
}
