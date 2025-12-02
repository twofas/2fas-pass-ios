// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ItemDetailFormTags: View {
    
    let tags: String?
    
    init(_ tags: String?) {
        self.tags = tags
    }
    
    var body: some View {
        if let tags {
            LabeledContent(T.loginTags.localizedKey, value: tags)
                .labeledContentStyle(.listCell(lineLimit: nil))
        }
    }
}
