// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Lottie
import CommonUI

private struct Constants {
    static let animationMaxHeight = 328.0
    static let featureIconSize = 28.0
}

struct OnboardingPageView: View {
    
    @State
    var presenter: OnboardingPagePresenter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LottieSchemedAnimationView(baseNamed: presenter.onboardingPage.animationName) {
                $0.looping()
            }
            .frame(minHeight: 0, maxHeight: Constants.animationMaxHeight)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: OnboardingPageViewAnimationHeightPreferenceKey.self, value: proxy.size.height)
                }
            }
            .background(Color.neutral50)
            
            Text(presenter.onboardingPage.title)
                .font(.title1Emphasized)
                .foregroundStyle(.neutral950)
                .padding(.top, Spacing.xll)
                .padding(.bottom, Spacing.s)
                .padding(.horizontal, Spacing.xl)
            
            Text(presenter.onboardingPage.subtitle)
                .font(.subheadline)
                .foregroundStyle(.neutral600)
                .padding(.bottom, Spacing.xll2)
                .padding(.horizontal, Spacing.xl)
            
            VStack(alignment: .leading, spacing: Spacing.s) {
                ForEach(presenter.onboardingPage.features, id: \.id) {
                    featureView(for: $0)
                }
            }
            .padding(.horizontal, Spacing.xl)
            
            Spacer()
        }
    }
    
    private func featureView(for feature: OnboardingPage.Feature) -> some View {
        HStack(spacing: Spacing.s) {
            image(for: feature.icon)
                .frame(width: Constants.featureIconSize, height: Constants.featureIconSize)
                .foregroundStyle(.brand500)
            
            Text(feature.title)
                .font(.subheadline)
                .foregroundStyle(.neutral950)
        }
    }
    
    private func image(for icon: OnboardingPage.Feature.Icon) -> some View {
        switch icon {
        case .asset(let name):
            Image(name)
        case .sfSymbol(let name):
            Image(systemName: name)
        }
    }
    
    func onAnimationHeightChange(_ height: Binding<CGFloat>) -> some View {
        onPreferenceChange(OnboardingPageViewAnimationHeightPreferenceKey.self, perform: { animationHeight in
            height.wrappedValue = animationHeight
        })
    }
}

private struct OnboardingPageViewAnimationHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {}
}

#Preview {
    let presenter = OnboardingPagePresenter(
        onboardingPage: .init(
            animationName: "ios-onboarding-01",
            title: "Connect with web browser",
            subtitle: "Securely create and fill in passwords when surfing online.",
            features: [
                .init(
                    icon: .sfSymbol("iphone.radiowaves.left.and.right"),
                    title: "Synchronize your passwords with your PC"
                ),
                .init(
                    icon: .sfSymbol("lock.shield"),
                    title: "End-to-end encryption on your device"
                ),
                .init(
                    icon: .sfSymbol("lock.slash.fill"),
                    title: "Generates unique password"
                )
            ]
        )
    )
    OnboardingPageView(presenter: presenter)
}
