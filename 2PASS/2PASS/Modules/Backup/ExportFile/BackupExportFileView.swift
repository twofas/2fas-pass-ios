// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupExportFileView: View {

    @State
    var presenter: BackupExportFilePresenter
    
    var body: some View {
        VStack(spacing: Spacing.xll2) {
            HeaderContentView(
                title: Text(T.backupExportSaveTitle.localizedKey),
                subtitle: Text(T.backupExportSaveSubtitle.localizedKey),
                icon: {
                    Image(.lockFileHeaderIcon)
                }
            )
            
            Spacer()
                        
            InfoToggle(
                title: Text(T.backupExportSaveEncryptToggleTitle.localizedKey),
                description: Text(T.backupExportSaveEncryptToggleDescription.localizedKey),
                isOn: $presenter.encryptFile
            )
            .disabled(presenter.isExporting)
            
            Button {
                presenter.onExport()
            } label: {
                Text(T.backupExportSaveCta.localizedKey)
                    .accessoryLoader(presenter.isExporting)
            }
            .buttonStyle(.filled)
            .allowsHitTesting(presenter.isExporting == false)
            .controlSize(.large)
        }
        .padding(.vertical, Spacing.l)
        .padding(.horizontal, Spacing.xl)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            presenter.onDisappear()
        }
        .router(router: BackupExportFileRouter(), destination: $presenter.destination)
        .readableContentMargins()
    }
}

#Preview {
    NavigationStack {
        BackupExportFileView(presenter: .init(interactor: ModuleInteractorFactory.shared.backupExportFileModuleInteractor(), onClose: {}))
    }
}
