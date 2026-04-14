// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

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
            .padding(.horizontal, Spacing.xl)

            Spacer()

            VStack(spacing: Spacing.l) {
                if presenter.hasMultipleVaults {
                    vaultPicker
                        .disabled(presenter.isExporting)
                }
                
                InfoToggle(
                    title: Text(.backupExportSaveEncryptToggleTitle),
                    description: Text(.backupExportSaveEncryptToggleDescription),
                    isOn: $presenter.encryptFile
                )
                .disabled(presenter.isExporting)
                .padding(.horizontal, Spacing.xl)
            }
            
            Button {
                presenter.onExport()
            } label: {
                Text(.backupExportSaveCta)
                    .accessoryLoader(presenter.isExporting)
            }
            .buttonStyle(.filled)
            .allowsHitTesting(presenter.isExporting == false)
            .controlSize(.large)
            .padding(.horizontal, Spacing.xl)
        }
        .padding(.vertical, Spacing.l)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            presenter.onDisappear()
        }
        .router(router: BackupExportFileRouter(), destination: $presenter.destination)
        .readableContentMargins()
    }

    private var vaultPicker: some View {
        GroupedSection {
            HStack {
                Text("Vault")
                
                Spacer()
                
                Picker(selection: $presenter.selectedVaultID) {
                    ForEach(presenter.availableVaults, id: \.vaultID) { vault in
                        Text(vault.name).tag(vault.vaultID)
                    }
                } label: {
                    EmptyView()
                }
            }
            .groupedRowBackground(Color.neutral50)
        }
    }
}

#Preview {
    NavigationStack {
        BackupExportFileView(presenter: .init(interactor: ModuleInteractorFactory.shared.backupExportFileModuleInteractor(), onClose: {}))
    }
}
