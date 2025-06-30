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
                    Text(T.restoreReadingFileText.localizedKey)
                })
                .progressViewStyle(.circular)
                .tint(nil)
                .controlSize(.large)
            case .decrypted:
                ResultView(
                    kind: .info,
                    title: Text(T.restoreUnencryptedFileTitle.localizedKey),
                    description: Text(T.restoreUnencryptedFileDescription.localizedKey),
                    action: {
                        VStack(spacing: Spacing.m) {
                            Text(T.restoreUnencryptedFileCtaDescriptionIos.localizedKey)
                                .lineSpacing(2)
                                .font(.caption)
                                .foregroundStyle(.neutral600)
                            
                            Button(T.commonTryAgain.localizedKey) {
                                dismiss()
                            }
                        }
                    }
                )
            case .error(let error):
                ResultView(
                    kind: .failure,
                    title: Text(T.commonError.localizedKey),
                    description: Text(error),
                    action: {
                        Button(T.commonTryAgain.localizedKey) {
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
