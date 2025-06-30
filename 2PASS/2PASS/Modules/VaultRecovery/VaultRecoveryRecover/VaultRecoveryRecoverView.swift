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
    
    @Environment(\.dismiss)
    private var dismiss
    
    @Environment(\.dismissFlow)
    private var dismissFlow
    
    var body: some View {
        ZStack {
            switch presenter.state {
            case .loading:
                ProgressView(label: {
                    Text(T.restoreImportingFileText.localizedKey)
                })
                .progressViewStyle(.circular)
                .tint(nil)
                .controlSize(.large)
            case .success:
                ResultView(
                    kind: .success,
                    title: Text(T.restoreSuccessTitle.localizedKey),
                    description: Text(T.restoreSuccessDescription.localizedKey),
                    action: {
                        Button(T.restoreSuccessCta.localizedKey) {
                            dismissFlow()
                        }
                    }
                )
            case .error:
                ResultView(
                    kind: .failure,
                    title: Text(T.restoreFailureTitle.localizedKey),
                    description: Text(T.restoreFailureDescription.localizedKey),
                    action: {
                        Button(T.commonTryAgain.localizedKey) {
                            dismiss()
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
