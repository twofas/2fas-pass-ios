// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let minHeightNotes: CGFloat = 80
}

struct SecureNoteDetailFormView: View {
    
    let presenter: SecureNoteFormPresenter
    
    var body: some View {
        ItemDetalFormTitle(name: presenter.name, icon: .contentType(.secureNote))
        
        if presenter.isReveal {
            Text(presenter.note ?? "")
                .frame(maxWidth: .infinity, minHeight: Constants.minHeightNotes, alignment: .topLeading)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.neutral200)
                
                Button("Tap to view") {
                    presenter.onViewNote()
                }
                .contentShape(Rectangle())
                .padding(.bottom, Spacing.xs)
            }
            .frame(maxWidth: .infinity, minHeight: Constants.minHeightNotes, alignment: .center)
        }
        
        ItemDetailFormProtectionLevel(presenter.protectionLevel)
        ItemDetailFormTags(presenter.tags)
    }
}
