// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct BackupExportFileFailureView: View {
    
    let onClose: Callback
    
    var body: some View {
        ResultView(
            kind: .success,
            title: Text(T.backupExportFailedTitle.localizedKey),
            description: Text(T.backupExportFailedDescription.localizedKey),
            action: {
                Button(T.commonContinue.localizedKey) {
                    onClose()
                }
            }
        )
    }
}
