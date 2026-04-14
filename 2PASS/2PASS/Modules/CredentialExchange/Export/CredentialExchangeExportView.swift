// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

@available(iOS 26.0, *)
struct CredentialExchangeExportView: View {

    @State var presenter: CredentialExchangeExportPresenter

    var body: some View {
        VStack(spacing: Spacing.xll) {
            Spacer()

            VStack(spacing: Spacing.s) {
                Text(.credentialExchangeExportTitle)
                    .font(.title1Emphasized)
                    .foregroundStyle(.neutral950)

                Text(.credentialExchangeExportDescription)
                    .font(.subheadline)
                    .foregroundStyle(.neutral600)
            }

            Spacer()

            VStack(spacing: Spacing.l) {
                if presenter.hasMultipleVaults {
                    vaultPicker
                        .disabled(isExporting)
                }
                
                Button(.credentialExchangeExportCta) {
                    presenter.startExport()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
                .disabled(isExporting)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .readableContentMargins()
        .router(router: CredentialExchangeExportRouter(), destination: $presenter.destination)
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

    private var isExporting: Bool {
        if case .exporting = presenter.state { return true }
        return false
    }
}
