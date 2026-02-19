// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct PasswordGeneratorRouter {
    @ViewBuilder
    public static func buildView(close: @escaping Callback, closeUsePassword: @escaping (String) -> Void) -> some View {
        PasswordGeneratorView(
            presenter: PasswordGeneratorPresenter(
                close: close,
                closeUsePassword: closeUsePassword,
                interactor: ModuleInteractorFactory.shared.passwordGeneratorModuleInteractor()
            )
        )
    }
}
