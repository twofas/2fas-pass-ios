// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryCheckView: View {
    
    @State
    var presenter: VaultRecoveryCheckPresenter
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        VStack {
            switch presenter.state {
            case .checking:
                ProgressView(label: {
                    Text(.restoreReadingFileText)
                })
                .progressViewStyle(.circular)
                .tint(nil)
                .controlSize(.large)
            case .decrypted:
                ResultView(
                    kind: .info,
                    title: Text(.restoreUnencryptedFileTitle),
                    description: Text(.restoreUnencryptedFileDescription),
                    action: {
                        VStack(spacing: Spacing.m) {
                            Text(.restoreUnencryptedFileCtaDescriptionIos)
                                .lineSpacing(2)
                                .font(.caption)
                                .foregroundStyle(.neutral600)
                            
                            Button(.commonTryAgain) {
                                dismiss()
                            }
                        }
                    }
                )
            case .error(let error):
                ResultView(
                    kind: .failure,
                    title: Text(.commonError),
                    description: Text(error),
                    action: {
                        Button(.commonTryAgain) {
                            dismiss()
                        }
                    }
                )
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .background(Color(Asset.mainBackgroundColor.color))
    }
}
