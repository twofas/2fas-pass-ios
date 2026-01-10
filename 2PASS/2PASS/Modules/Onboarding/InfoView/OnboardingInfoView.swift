// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct OnboardingInfoView: View {
    @Bindable
    var presenter: OnboardingInfoPresenter
    @Environment(\.dismiss) var dismiss

    var body: some  View {
        VStack(alignment: .leading, spacing: 0) {
            Asset.onboardingInfo.swiftUIImage
                .frame(height: 210)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(.onboardingCreateMasterPasswordGuideTitle)
                    .foregroundStyle(.neutral950)
                    .font(.title1Emphasized)
                    .padding(.top, Spacing.xl)
                
                Text(.onboardingCreateMasterPasswordGuideDescription)
                    .foregroundStyle(.neutral600)
                    .font(.subheadline)
                    .padding(.top, Spacing.s)
                
                VStack(alignment: .leading, spacing: Spacing.xll) {
                    ForEach(presenter.guideItems, id: \.id) { guideItem in
                        guideItemView(for: guideItem)
                    }
                }
                .padding(.top, Spacing.xll)
                
                Spacer()
                
                Button(.commonClose) {
                    dismiss()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
            }
            .padding(.horizontal, Spacing.xl)
        }
    }
    
    private func guideItemView(for guideItem: OnboardingInfoPresenter.OnboardingGuideItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            guideItem.image
                .frame(width: 32, height: 32)
                .foregroundStyle(.brand500)
            
            Text(guideItem.message)
                .foregroundStyle(.neutral950)
                .font(.subheadline)
        }
    }
}

#Preview {
    OnboardingInfoView(presenter: .init())
}
