// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupView: View {
    
    @State
    var presenter: BackupPresenter
    
    var body: some View {
        SettingsDetailsForm(.settingsEntryImportExport) {
            Section {
                Button(.backupImportCta) {
                    presenter.onImport()
                }
            } header: {
                Text(.backupImportHeader)
                    .padding(.top, Spacing.l)
            } footer: {
                Text(.backupImportFooter)
                    .settingsFooter()
            }
            
            Section {
                Button {
                    presenter.onExport()
                } label: {
                    SettingsRowView(
                        title: .backupExportCta,
                        actionIcon: .chevron
                    )
                }
                .disabled(presenter.isExportDisabled)
                
            } header: {
                Text(.backupExportHeader)
            } footer: {
                Text(.backupExportFooter)
                    .settingsFooter()
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .toolbar {
            if presenter.flowContext.kind == .quickSetup {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        presenter.flowContext.onClose?()
                    }
                }
            }
        }
        .router(router: BackupRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        BackupView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.backupModuleInteractor(),
            flowContext: .settings
        ))
    }
}
