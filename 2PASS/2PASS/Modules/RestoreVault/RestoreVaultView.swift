// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct RestoreVaultView: View {
    
    @State
    var presenter: VaultRecoverySelectPresenter
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderContentView(
                title: Text(.restoreVaultTitle),
                subtitle: Text(.restoreVaultMessage),
                icon: {
                    Image(._2PASSShield)
                }
            )
            .padding(.top, Spacing.xxl4)
            .padding(.vertical, Spacing.l)

            SelectDecryptionMethod(
                onFiles: { presenter.onFiles() },
                onCamera: { presenter.onCamera() },
                onEnterManually: { presenter.onEnterManually() }
            )
            .padding(.top, Spacing.xll)
            
            Spacer()
            
            VStack(spacing: Spacing.m) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.warning600)
                
                Text(.restoreVaultWarning)
                    .font(.subheadline)
                    .foregroundStyle(.warning600)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, Spacing.l)
        }
        .padding(.horizontal, Spacing.xl)
        .router(router: VaultRecoverySelectRouter(), destination: $presenter.destination)
        .background(Color(Asset.mainBackgroundColor.color))
        .readableContentMargins()
        .fileImporter(
            isPresented: $presenter.showFileImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            onCompletion: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let url): presenter.onFileOpen(url)
                    case .failure(let error): presenter.onFileError(error)
                    }
                }
            })
    }
}

#Preview {
    RestoreVaultView(presenter: .init(flowContext: .restoreVault, interactor: ModuleInteractorFactory.shared.vaultRecoverySelectModuleInteractor(), recoveryData: .localVault))
}
