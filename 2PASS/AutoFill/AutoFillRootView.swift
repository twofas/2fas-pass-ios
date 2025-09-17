// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct AutoFillRootView: View {
    
    @Bindable var presenter: AutoFillRootPresenter
    
    var body: some View {
        switch presenter.startupResult {
        case .enterPassword, .enterWords, .selectVault:
            noVaultView
        case .login:
            if presenter.isLogged {
                AutoFillPasswordsListView(
                    context: presenter.extensionContext,
                    serviceIdentifiers: presenter.serviceIdentifiers,
                    isTextToInsert: presenter.isTextToInsert
                )
                .ignoresSafeArea()
            } else {
                NavigationStack {
                    LoginView(presenter: presenter.loginPresenter)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                ToolbarCancelButton {
                                    presenter.onCancel()
                                }
                            }
                        }
                }
            }
        }
    }
    
    private var noVaultView: some View {
        NavigationStack {
            Text("autofill_no_vault_message")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarCancelButton {
                            presenter.onCancel()
                        }
                    }
                }
        }
    }
}
