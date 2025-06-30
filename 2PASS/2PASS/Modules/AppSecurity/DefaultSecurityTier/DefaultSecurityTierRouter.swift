// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct DefaultSecurityTierRouter {
    
    @MainActor
    static func buildView() -> some View {
        DefaultSecurityTierView(presenter: .init(interactor: ModuleInteractorFactory.shared.defaultSecurityTierModuleInteractor()))
    }
}
