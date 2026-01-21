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
                title: Text(.backupExportSaveTitle),
                subtitle: Text(.backupExportSaveSubtitle),
                icon: {
                    Image(.lockFileHeaderIcon)
                }
            )
            
            Spacer()
                        
            InfoToggle(
                title: Text(.backupExportSaveEncryptToggleTitle),
                description: Text(.backupExportSaveEncryptToggleDescription),
                isOn: $presenter.encryptFile
            )
            .disabled(presenter.isExporting)
            
            Button {
                presenter.onExport()
            } label: {
                Text(.backupExportSaveCta)
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
