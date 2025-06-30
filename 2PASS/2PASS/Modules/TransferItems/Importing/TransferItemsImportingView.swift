// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct TransferItemsImportingView: View {
    
    @State var presenter: TransferItemsImportingPresenter
    
    var body: some View {
        ZStack {
            switch presenter.state {
            case .importing:
                ProgressView(label: {
                    Text(T.backupImportingFileText.localizedKey)
                })
                .progressViewStyle(.circular)
                .tint(nil)
                .controlSize(.large)
                
            case .success:
                TransferItemsSuccessView(onClose: presenter.onClose)
            }
        }
        .navigationBarBackButtonHidden()
        .task {
            await presenter.onAppear()
        }
    }
}
