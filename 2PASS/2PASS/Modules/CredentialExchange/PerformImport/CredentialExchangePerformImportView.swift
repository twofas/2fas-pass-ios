// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import SwiftUI

@available(iOS 26.0, *)
struct CredentialExchangePerformImportView: View {

    @State var presenter: CredentialExchangePerformImportPresenter

    var body: some View {
        Group {
            switch presenter.state {
            case .importing:
                ProgressView {
                    Text(.credentialExchangeImportingDescription)
                }
                .progressViewStyle(.circular)
                .tint(nil)
                .controlSize(.large)

            case .success:
                ResultView(
                    kind: .success,
                    title: Text(.credentialExchangeImportSuccessTitle),
                    description: Text(.credentialExchangeImportSuccessDescription)
                ) {
                    Button(.commonContinue) {
                        presenter.onClose()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden()
        .task {
            await presenter.onAppear()
        }
    }
}
