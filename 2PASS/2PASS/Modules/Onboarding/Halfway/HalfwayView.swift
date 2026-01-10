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
                title: Text(.onboardingProgressHalfwayTitle),
                subtitle: Text(.onboardingProgressHalfwayDescription)
            )
            
            VStack(spacing: 0) {
                Text(.onboardingProgressStepsHeader)
                    .font(.footnote)
                    .foregroundStyle(.neutral500)
                    .padding(.bottom, Spacing.m)
                
                OnboardingStepDimmedView(
                    title: .onboardingProgressStep1Title,
                    subtitle: .onboardingProgressStep1Description,
                    isChecked: firstStepCompleted,
                    isTitleStrikethrough: false,
                    areTextsGreyedOut: selectedStep == 1
                )
                .matchedGeometryEffect(id: 0, in: namespace)
                .padding(.bottom, Spacing.s)
                
                OnboardingStepDimmedView(
                    title: .onboardingProgressStep2Title,
                    subtitle: .onboardingProgressStep2Description,
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
            
            Button(.onboardingCreateMasterPasswordTitle) {
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
