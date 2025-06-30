// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct ConnectPermissionsRouter {
    
    static func buildView(onFinish: @escaping Callback) -> some View {
        ConnectPermissionsView(presenter: .init(interactor: ModuleInteractorFactory.shared.connectPermissionsModuleInteractor()))
            .environment(\.dismissFlow, .init(action: onFinish))
    }
}
