// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

enum ChangePasswordPromptDestination: RouterDestination {
    case changeMasterPassword(onFinish: Callback, onClose: Callback)

    var id: String {
        switch self {
        case .changeMasterPassword: "changeMasterPassword"
        }
    }
}

struct ChangePasswordPromptRouter: Router {

    static func buildView(onClose: @escaping Callback) -> some View {
        NavigationStack {
            ChangePasswordPromptView(presenter: .init(
                interactor: ModuleInteractorFactory.shared.changePasswordPromptModuleInteractor(),
                onClose: onClose
            ))
        }
    }

    @ViewBuilder
    func view(for destination: ChangePasswordPromptDestination) -> some View {
        switch destination {
        case .changeMasterPassword(let onFinish, let onClose):
            NavigationStack {
                MasterPasswordRouter.buildView(kind: .change, onFinish: onFinish, onClose: onClose)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            ToolbarCancelButton(action: onClose)
                        }
                    }
            }
        }
    }

    func routingType(for destination: ChangePasswordPromptDestination?) -> RoutingType? {
        switch destination {
        case .changeMasterPassword: .fullScreenCover
        case nil: nil
        }
    }
}
