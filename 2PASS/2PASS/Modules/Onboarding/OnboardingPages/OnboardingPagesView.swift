// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct OnboardingPagesView: View {
    
    @State
    var presenter: OnboardingPagesPresenter
    
    @State
    private var animationHeight: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                ForEach(presenter.pages, id: \.id) { page in
                    OnboardingPageView(presenter: .init(onboardingPage: page))
                        .onAnimationHeightChange($animationHeight)
                        .readableContentMargins()
                }
                .padding(.bottom, 48)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            VStack(spacing: 8) {
                Button(T.onboardingWelcomeCta1.localizedKey) {
                    presenter.onGetStartedTap()
                }
                .buttonStyle(.filled)
                
                Button(T.onboardingWelcomeCta2.localizedKey) {
                    presenter.onRecoverTap()
                }
                .buttonStyle(.twofasBorderless)
                .controlSize(.large)
            }
            .controlSize(.large)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.m)
            .readableContentMargins()
        }
        .background(alignment: .top) {
            GeometryReader { proxy in
                Color.neutral50
                    .frame(height: proxy.safeAreaInsets.top + animationHeight)
                    .ignoresSafeArea()
            }
        }
        .router(router: OnboardingPagesRouter(), destination: $presenter.destination)
    }
}

#Preview {
    OnboardingPagesRouter.buildView(onLogin: {})
}
