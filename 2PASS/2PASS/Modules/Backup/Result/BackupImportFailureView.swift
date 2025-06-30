// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct BackupImportFailureView: View {
    
    let onClose: Callback
    
    var body: some View {
        ResultView(
            kind: .failure,
            title: Text(T.backupImportingFailureTitle),
            description: Text(T.backupImportingFailureDescription),
            action: {
                Button(T.commonContinue.localizedKey) {
                    onClose()
                }
            }
        )
    }
}
