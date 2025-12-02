// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ItemDetailFormNotes: View {
    
    let notes: String?
    
    init(_ notes: String?) {
        self.notes = notes
    }
    
    var body: some View {
        if let notes, notes.isEmpty == false {
            HStack {
                Text(notes)
                    .multilineTextAlignment(.leading)
                    .font(.body)
                    .foregroundStyle(.neutral400)

                Spacer(minLength: 0)
            }
        }
    }
}
