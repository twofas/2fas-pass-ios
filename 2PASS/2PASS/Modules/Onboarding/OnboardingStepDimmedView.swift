// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct OnboardingStepDimmedView: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let isSelected: Bool
    let isChecked: Bool
    let isTitleStrikethrough: Bool
    let areTextsGreyedOut: Bool
    
    init(title: LocalizedStringResource,
         subtitle: LocalizedStringResource,
         isSelected: Bool = false,
         isChecked: Bool = false,
         isTitleStrikethrough: Bool = false,
         areTextsGreyedOut: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isChecked = isChecked
        self.isTitleStrikethrough = isTitleStrikethrough
        self.areTextsGreyedOut = areTextsGreyedOut
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.calloutEmphasized)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .frame(height: 1)
                            .frame(maxWidth: isChecked ? .infinity : 0)
                    }
                    .foregroundStyle(.neutral950)
                    .animation(.linear(duration: 0.3), value: isChecked)
                
                Text(subtitle)
                    .foregroundStyle(.neutral500)
                    .font(.footnote)
            }
            .opacity(areTextsGreyedOut ? 0.5 : 1)
            
            Spacer(minLength: 0)
            
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(.brand500)
                .opacity(isChecked ? 1 : 0)
                .animation(.easeInOut(duration: 0.4).delay(0.2), value: isChecked)
        }
        .padding(Spacing.l)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.neutral50)
                .opacity(areTextsGreyedOut ? 0.5 : 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.brand300, lineWidth: isSelected ? 2 : 0)
                .opacity(areTextsGreyedOut ? 0.5 : 1)
                .animation(.easeInOut, value: isSelected)
        )
    }
}

#Preview {
    OnboardingStepDimmedView(
        title: "Title",
        subtitle: "Subtitle",
        isSelected: true,
        isChecked: true,
        isTitleStrikethrough: true,
        areTextsGreyedOut: true
    )
    .padding(.horizontal, 16)
}
