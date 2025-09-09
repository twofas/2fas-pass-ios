// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct BackupSchemaNotSupportedView: View {
    
    let schemeVersion: Int
    let expectedSchemeVersion: Int
    let onClose: Callback
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ResultView(
            kind: .failure,
            title: Text(T.backupImportingFailureTitle),
            description: Text(T.importInvalidSchemaErrorMsg(expectedSchemeVersion, schemeVersion)),
            action: {
                VStack {
                    Button(T.importInvalidSchemaErrorCta.localizedKey) {
                        openURL(Config.appStoreURL)
                    }
                    
                    Button(T.commonClose.localizedKey) {
                        onClose()
                    }
                    .buttonStyle(.twofasBorderless)
                }
            }
        )
    }
}
