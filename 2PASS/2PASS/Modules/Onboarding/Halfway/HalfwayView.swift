// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let markFirstStepAsFinishedDelay: Duration = .milliseconds(500)
    static let selectSecondStepDelay: Duration = .milliseconds(600)
    static let selectStepFeedbackDelay: Duration = .milliseconds(100)
    
    static let showContinueButtonDelay = 0.1
    static let changeOpacitySecondStepDelay = 0.2
    static let moveSelectedFrameAnimationDuration = 0.4
    
    static let unselectedStepOpacity: Double = 0.5
    static let stepProgress: Float = 0.5
    
    struct SelectedStepFrame {
        static let cornerRadius = 10.0
        static let lineWidth: CGFloat = 2.0
    }
    
    struct FullFrame {
        static let cornerRadius = 24.0
        static let lineWidth: CGFloat = 1.0
    }
}

struct HalfwayView: View {
    
    @State
    var presenter: HalfwayPresenter

    @Namespace private var namespace
    
    @State private var firstStepCompleted = false
    @State private var selectedStep = 0
    @State private var selectedStepFeedback = false
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderContentView(
                title: Text(T.onboardingProgressHalfwayTitle.localizedKey),
                subtitle: Text(T.onboardingProgressHalfwayDescription.localizedKey)
            )
            
            VStack(spacing: 0) {
                Text(T.onboardingProgressStepsHeader.localizedKey)
                    .font(.footnote)
                    .foregroundStyle(.neutral500)
                    .padding(.bottom, Spacing.m)
                
                OnboardingStepDimmedView(
                    title: T.onboardingProgressStep1Title.localizedKey,
                    subtitle: T.onboardingProgressStep1Description.localizedKey,
                    isChecked: firstStepCompleted,
                    isTitleStrikethrough: false,
                    areTextsGreyedOut: selectedStep == 1
                )
                .matchedGeometryEffect(id: 0, in: namespace)
                .padding(.bottom, Spacing.s)
                
                OnboardingStepDimmedView(
                    title: T.onboardingProgressStep2Title.localizedKey,
                    subtitle: T.onboardingProgressStep2Description.localizedKey,
                    isSelected: false
                )
                .opacity(selectedStep == 1 ? 1 : Constants.unselectedStepOpacity)
                .animation(.default.delay(Constants.changeOpacitySecondStepDelay), value: selectedStep == 1)
                .matchedGeometryEffect(id: 1, in: namespace)
            }
            .sensoryFeedback(.selection, trigger: selectedStepFeedback)
            .overlay {
                RoundedRectangle(cornerRadius: Constants.SelectedStepFrame.cornerRadius)
                    .stroke(.brand300, lineWidth: Constants.SelectedStepFrame.lineWidth)
                    .matchedGeometryEffect(id: selectedStep, in: namespace, isSource: false)
                    .animation(.smooth(duration: Constants.moveSelectedFrameAnimationDuration), value: selectedStep)
            }
            .padding(Spacing.s)
            .overlay {
                RoundedRectangle(cornerRadius: Constants.FullFrame.cornerRadius)
                    .stroke(.neutral100, lineWidth: Constants.FullFrame.lineWidth)
            }
            .padding(.top, Spacing.xll3)
            .padding(.horizontal, Spacing.xl)
            
            Spacer()
            
            Button(T.onboardingCreateMasterPasswordTitle.localizedKey) {
                presenter.onCreateMasterPasswordTap()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .opacity(selectedStep == 1 ? 1 : 0)
            .animation(.easeInOut.delay(Constants.showContinueButtonDelay), value: selectedStep == 1)
            .padding(.bottom, Spacing.xl)
            .padding(.horizontal, Spacing.xl)
        }
        .onAppear {
            Task {
                try await Task.sleep(for: Constants.markFirstStepAsFinishedDelay)
                firstStepCompleted = true
                
                try await Task.sleep(for: Constants.selectSecondStepDelay)
                selectedStep = 1
                
                try await Task.sleep(for: Constants.selectStepFeedbackDelay)
                selectedStepFeedback = true
            }
        }
        .onboardingStepProgress(Constants.stepProgress)
        .onboardingStepTopPadding()
        .router(router: HalfwayRouter(), destination: $presenter.destination)
        .readableContentMargins()
    }
}

#Preview {
    OnboardingStepsStack {
        HalfwayRouter.buildView()
    }
}
