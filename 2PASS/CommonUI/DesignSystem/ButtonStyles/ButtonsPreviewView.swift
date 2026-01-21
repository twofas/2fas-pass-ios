// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ButtonsPreviewView: View {
    
    let layout: ButtonLayoutType
    
    init(layout: ButtonLayoutType = .rectangle) {
        self.layout = layout
    }
    
    var body: some View {
        let image = Image(systemName: "play.fill")
        let content = VStack(spacing: 4) {
            switch layout {
            case .rectangle:
                Button("Play" as String, symbol: image) {}
            case .circle:
                Button(symbol: image) {}
            }
            Button("Delete" as String, role: .destructive) {}
        }
        
        VStack {
            content
                .controlSize(.small)
            content
                .controlSize(.regular)
            content
                .controlSize(.large)
        }
        .padding(.horizontal, 12)
    }
}
