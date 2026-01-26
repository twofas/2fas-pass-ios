// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct LoginRouter: Router {

    public init() {}
    
    public static func buildView(config: LoginModuleInteractorConfig, onSuccess: @escaping Callback) -> some View {
        NavigationStack {
            LoginView(presenter: .init(
                loginSuccessful: onSuccess,
                interactor: ModuleInteractorFactory.shared.loginModuleInteractor(
                    config: config
                )
            ))
        }
    }

    @MainActor @ViewBuilder
    public func view(for destination: LoginDestination) -> some View {
        switch destination {
        case .forgotMasterPassword:
            ForgotMasterPasswordRouter.buildView()
        }
    }
    
    public func routingType(for destination: LoginDestination?) -> RoutingType? {
        switch destination {
        case .forgotMasterPassword:
            return .fullScreenCover
        case nil:
            return nil
        }
    }
}
