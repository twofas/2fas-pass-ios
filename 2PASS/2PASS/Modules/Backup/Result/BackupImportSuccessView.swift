// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct BackupImportSuccessView: View {
    
    let onClose: Callback
    
    var body: some View {
        ResultView(
            kind: .success,
            title: Text(.backupImportingSuccessTitle),
            description: Text(.backupImportingSuccessDescription),
            action: {
                Button(.commonContinue) {
                    onClose()
                }
            }
        )
    }
}
