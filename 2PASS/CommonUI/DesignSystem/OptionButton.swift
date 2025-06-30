// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension ButtonStyle where Self == OptionButtonStyle {
    public static var option: Self { .init() }
}

public struct OptionButtonStyle: ButtonStyle {
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? .neutral100 : .neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

public struct OptionButtonLabel<Icon>: View where Icon: View {
    
    let title: Text
    let subtitle: Text?
    let icon: Icon?
    
    public init(title: Text, subtitle: Text? = nil, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon()
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: Spacing.l) {
                if let icon {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .stroke(Color(UIColor(hexString: "#E5E5EA")!), style: .init(lineWidth: 0.5))
                        .overlay {
                            icon
                                .foregroundStyle(.brand500)
                                .font(.system(size: 30))
                                .colorScheme(.light)
                        }
                        .frame(width: 64, height: 64)
                }
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    title
                        .foregroundStyle(.neutral950)
                        .font(.bodyEmphasized)
                    
                    subtitle
                        .foregroundStyle(.neutral600)
                        .font(.footnote)
                }
                .multilineTextAlignment(.leading)
                .padding(.leading, icon == nil ? 8 : 0)
                .padding(.vertical, icon == nil ? 4 : 0)
            }
            
            Spacer(minLength: 0)
            
            Image(systemName: "chevron.forward")
                .foregroundStyle(.neutral500)
                .frame(width: 20, height: 20)
                .padding(.trailing, 4)
        }
        .padding(8)
    }
}

extension OptionButtonLabel where Icon == EmptyView {
    
    public init(title: Text, subtitle: Text? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = nil
    }
}
