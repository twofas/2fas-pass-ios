// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryRecoverView: View {
    
    @State
    var presenter: VaultRecoveryRecoverPresenter

    @Environment(\.dismissFlow)
    private var dismissFlow
    
    var body: some View {
        ZStack {
            switch presenter.state {
            case .loading:
                ProgressView(label: {
                    Text(.restoreImportingFileText)
                })
                .progressViewStyle(.circular)
                .tint(nil)
                .controlSize(.large)
            case .success:
                ResultView(
                    kind: .success,
                    title: Text(.restoreSuccessTitle),
                    description: Text(.restoreSuccessDescription),
                    action: {
                        Button(.restoreSuccessCta) {
                            dismissFlow()
                        }
                    }
                )
            case .error:
                ResultView(
                    kind: .failure,
                    title: Text(.restoreFailureTitle),
                    description: Text(.restoreFailureDescription),
                    action: {
                        Button(.commonTryAgain) {
                            presenter.handleTryAgain()
                        }
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.1), value: presenter.state)
        .onAppear {
            presenter.onAppear()
        }
        .navigationBarBackButtonHidden()
    }
}
