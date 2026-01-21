// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct BackupSchemaNotSupportedView: View {
    
    let schemaVersion: Int
    let onClose: Callback
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ResultView(
            kind: .failure,
            title: Text(.backupImportingFailureTitle),
            description: Text(.importInvalidSchemaErrorMsg(Int32(schemaVersion))),
            action: {
                VStack {
                    Button(.importInvalidSchemaErrorCta) {
                        openURL(Config.appStoreURL)
                    }
                    
                    Button(.commonClose) {
                        onClose()
                    }
                    .buttonStyle(.twofasBorderless)
                }
            }
        )
    }
}
