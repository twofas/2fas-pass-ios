// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupImportImportingView: View {
    
    @State
    var presenter: BackupImportImportingPresenter
    
    var body: some View {
        Group {
            switch presenter.state {
            case .importing:
                ProgressView(label: {
                    Text(T.backupImportingFileText.localizedKey)
                })
                .progressViewStyle(.circular)
                .tint(nil)
                .controlSize(.large)
                
            case .success:
                BackupImportSuccessView(onClose: presenter.onClose)
                
            case .failure:
                BackupImportFailureView(onClose: presenter.onClose)
            }
        }
        .onAppear {
            presenter.onAppear()
        }
    }
}
