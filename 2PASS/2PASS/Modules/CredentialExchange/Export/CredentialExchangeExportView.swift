// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

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

            Button(.credentialExchangeExportCta) {
                presenter.startExport()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .disabled(isExporting)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .readableContentMargins()
        .router(router: CredentialExchangeExportRouter(), destination: $presenter.destination)
    }
    
    private var isExporting: Bool {
        if case .exporting = presenter.state { return true }
        return false
    }
}
