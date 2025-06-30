// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct AutofillSettingsRouter {

    static func buildView() -> some View {
        AutofillSettingsView(presenter: .init(interactor: ModuleInteractorFactory.shared.autoFillSettingsModuleInteractor()))
    }
}
