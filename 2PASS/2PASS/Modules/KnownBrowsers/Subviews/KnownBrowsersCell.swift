// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Data
import SVGView
import CommonUI

struct KnownBrowsersCell: View {
    
    let data: WebBrowser
    let identicon: String?
    
    var body: some View {
        HStack(spacing: Spacing.s) {
            ConnectIdenticonView(identicon: identicon)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(data.extName)
                    .font(.body)
                    .foregroundStyle(.neutral950)
                
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(T.knownBrowserLastConnectionPrefix.localizedKey) + Text(verbatim: " ") + Text(data.lastConnectionDate, format: .dateTime)
                    Text(T.knownBrowserFirstConnectionPrefix.localizedKey) + Text(verbatim: " ") + Text(data.firstConnectionDate, format: .dateTime)
                }
                .font(.caption2)
                .foregroundStyle(.neutral600)
            }
        }
    }
}
