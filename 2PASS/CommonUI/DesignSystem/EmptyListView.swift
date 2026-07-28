// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct EmptyListView<Icon>: View where Icon: View {
    
    let text: Text
    let icon: Icon?
    
    public init(_ text: Text, icon: Icon? = nil) {
        self.text = text
        self.icon = icon
    }
    
    public var body: some View {
        VStack(spacing: Spacing.xll) {
            if let icon {
                icon
            } else {
                Image(systemName: "tray.fill")
                    .font(.system(size: 50))
            }
            
            text
                .font(.subheadline)
        }
        .foregroundStyle(.neutral500)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xxl4)
    }
}

extension EmptyListView where Icon == EmptyView {
    
    public init(_ text: Text) {
        self.text = text
        self.icon = nil
    }
}

extension EmptyListView where Icon == EmptyView {
    
    public init(_ text: LocalizedStringResource) {
        self.init(Text(text))
    }
}

#Preview {
    EmptyListView(Text("There is no deleted data available at the moment."))
}
