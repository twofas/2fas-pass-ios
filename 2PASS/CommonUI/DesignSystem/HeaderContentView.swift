// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct HeaderContentView<Icon>: View where Icon: View {
    
    let title: Text
    let subtitle: Text?
    let icon: Icon?
    
    public init(title: Text, subtitle: Text? = nil, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon()
    }
    
    public var body: some View {
        VStack(spacing: Spacing.s) {
            icon?.font(.system(size: 50))
                .foregroundStyle(.brand500)
                .padding(.bottom, Spacing.l)
            
            title
                .foregroundStyle(.neutral950)
                .font(.title1Emphasized)
            
            subtitle
                .foregroundStyle(.neutral600)
                .font(.subheadline)
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
    }
}

extension HeaderContentView where Icon == EmptyView {
    
    public init(title: Text, subtitle: Text? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = nil
    }
}

extension HeaderContentView where Icon == Image {

    public init(title: Text, subtitle: Text? = nil, icon: Image) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }
}
