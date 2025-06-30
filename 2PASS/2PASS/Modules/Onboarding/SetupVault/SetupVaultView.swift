// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let appearAnimationDelay: Duration = .milliseconds(500)
    static let firstStepSelectedDelay: Duration = .milliseconds(1100)
    static let firstStepSelectedFeedbackDelay: Duration = .milliseconds(150)
    static let dimmedBorderDelay: Duration = .milliseconds(900)
    
    static let showFirstStepAnimationDuration: Double = 0.5
    static let showContinueButtonAnimationDuration = 0.25
    static let showTitleAnimationDuration: Double = 0.3
    static let drawFullFrameAnimationDuration = 0.7
    static let fullFrameDimmedAnimationDuration = 0.5
    
    static let showContinueButtonDelay = 1.3
    static let unselectedStepOpacity = 0.5

    static let firstStepAppearDelay = 0.3
    static let secondStepAppearDelay = 0.6
    
    static let stepAppearVerticalOffset: CGFloat = -30
    static let stepsTopPadding = 48.0

    static let fullFrameCornerRadius = 24.0
    
    static let initialFullFrameColor = Color(red: 163/255, green: 163/255, blue: 163/255)
    
    enum StepProgress {
        static let start: Float = 0.0
        static let end: Float = 0.1
    }
}

struct SetupVaultView: View {
    
    @State
    var presenter: SetupVaultPresenter

    @State private var appearAnimation = false
    @State private var dimmedBorder = false
    @State private var fisrstStepSelected = false
    @State private var firstStepSelectedFeedback = false
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderContentView(
                title: Text(T.onboardingProgressStartTitle.localizedKey),
                subtitle: Text(T.onboardingProgressStartDescription.localizedKey)
            )
            
            VStack(spacing: 0) {
                Text(T.onboardingProgressStepsHeader.localizedKey)
                    .font(.footnote)
                    .foregroundStyle(.neutral500)
                    .padding(.bottom, Spacing.m)
                    .opacity(appearAnimation ? 1 : 0)
                    .animation(.easeInOut(duration: Constants.showTitleAnimationDuration), value: appearAnimation)
                
                OnboardingStepDimmedView(
                    title: T.onboardingProgressStep1Title.localizedKey,
                    subtitle: T.onboardingProgressStep1Description.localizedKey,
                    isSelected: fisrstStepSelected
                )
                .offset(y: appearAnimation ? 0 : Constants.stepAppearVerticalOffset)
                .animation(.smooth(duration: Constants.showFirstStepAnimationDuration).delay(Constants.firstStepAppearDelay), value: appearAnimation)
                .opacity(fisrstStepSelected ? 1 : (appearAnimation ? Constants.unselectedStepOpacity : 0))
                .animation(.easeInOut, value: fisrstStepSelected)
                .animation(.easeInOut.delay(Constants.firstStepAppearDelay), value: appearAnimation)
                .padding(.bottom, Spacing.s)
                
                OnboardingStepDimmedView(
                    title: T.onboardingProgressStep2Title.localizedKey,
                    subtitle: T.onboardingProgressStep2Description.localizedKey
                )
                .offset(y: appearAnimation ? 0 : Constants.stepAppearVerticalOffset)
                .animation(.smooth.delay(Constants.secondStepAppearDelay), value: appearAnimation)
                .opacity(appearAnimation ? Constants.unselectedStepOpacity : 0)
                .animation(.easeInOut.delay(Constants.secondStepAppearDelay), value: appearAnimation)
            }
            .sensoryFeedback(.selection, trigger: firstStepSelectedFeedback)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.s)
            .overlay {
                fullFrame
            }
            .padding(.top, Constants.stepsTopPadding)
            .padding(.horizontal, Spacing.xl)
            
            Spacer()
            
            Button(T.commonContinue.localizedKey) {
                presenter.onGetStartedTap()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(.bottom, Spacing.xl)
            .padding(.horizontal, Spacing.xl)
            .opacity(appearAnimation ? 1 : 0)
            .animation(.easeInOut(duration: Constants.showContinueButtonAnimationDuration).delay(Constants.showContinueButtonDelay), value: appearAnimation)
        }
        .onboardingStepTopPadding()
        .onAppear {
            Task {
                try await Task.sleep(for: Constants.appearAnimationDelay)
                appearAnimation = true
                
                try await Task.sleep(for: Constants.firstStepSelectedDelay)
                fisrstStepSelected = true
                
                try await Task.sleep(for: Constants.firstStepSelectedFeedbackDelay)
                firstStepSelectedFeedback = true
            }
            
            Task {
                try await Task.sleep(for: Constants.dimmedBorderDelay)
                dimmedBorder = true
            }
        }
        .router(router: SetupVaultRouter(), destination: $presenter.destination)
        .onboardingStepProgress(appearAnimation ? Constants.StepProgress.end : Constants.StepProgress.start)
        .readableContentMargins()
    }
    
    private var fullFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.fullFrameCornerRadius)
                .trim(from: 0.25, to: 0.25 + (appearAnimation ? 1 : 0) * 0.5)
                .stroke(
                    dimmedBorder ? .neutral100 : Constants.initialFullFrameColor,
                    lineWidth: 1
                )
            
            RoundedRectangle(cornerRadius: Constants.fullFrameCornerRadius)
                .trim(from: 0.25, to: 0.25 + (appearAnimation ? 1 : 0) * 0.5)
                .stroke(
                    dimmedBorder ? .neutral100 : Constants.initialFullFrameColor,
                    lineWidth: 1
                )
                .scaleEffect(x: -1, y: 1)
        }
        .animation(.smooth(duration: Constants.drawFullFrameAnimationDuration), value: appearAnimation)
        .animation(.easeInOut(duration: Constants.fullFrameDimmedAnimationDuration), value: dimmedBorder)
        .scaleEffect(x: 1, y: -1)
    }
}

#Preview {
    OnboardingStepsStack {
        SetupVaultRouter.buildView()
    }
}
