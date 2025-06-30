// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let infoFrameCornerRadius = 16.0
    static let toggleWidth = 49.0
}

public struct InfoToggle: View {
    
    let icon: Image?
    let title: Text
    let description: Text
    @Binding var isOn: Bool
    
    public init(icon: Image? = nil, title: Text, description: Text, isOn: Binding<Bool>) {
        self.icon = icon
        self.title = title
        self.description = description
        self._isOn = isOn
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.infoFrameCornerRadius)
                .foregroundStyle(.neutral50)
            
            HStack(spacing: Spacing.m) {
                icon
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    title
                        .foregroundStyle(.neutral950)
                        .font(.calloutEmphasized)
                    
                    description
                        .foregroundStyle(.neutral600)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                }
                
                Toggle(isOn: $isOn) {}
                    .frame(width: Constants.toggleWidth)
            }
            .padding(Spacing.l)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
