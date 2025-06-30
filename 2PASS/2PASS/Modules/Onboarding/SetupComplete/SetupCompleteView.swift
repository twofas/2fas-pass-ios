// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI
import CommonUI

private struct Constants {
    static let firstStepCompletedDelay: Duration = .milliseconds(500)
    static let finishedDelay: Duration = .milliseconds(600)
    static let finishedFeedbackDelay: Duration = .milliseconds(100)
    
    static let showContinueButtonDelay = 0.1
    static let stepProgress: Float = 1.0
    
    struct FullFrame {
        static let cornerRadius = 24.0
        static let lineWidth: CGFloat = 1.0
    }
}

struct SetupCompleteView: View {
    
    @State
    var presenter: SetupCompletePresenter

    @Environment(\.dismissFlow) private var dismissFlow
    
    @State private var firstStepCompleted = false
    @State private var finished = false
    @State private var finishedFeedback = false
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderContentView(
                title: Text(T.onboardingProgressCompletedTitle.localizedKey),
                subtitle: Text(T.onboardingProgressCompletedDescription.localizedKey)
            )
            
            VStack(spacing: 0) {
                Text(T.onboardingProgressStepsHeader.localizedKey)
                    .font(.footnote)
                    .foregroundStyle(.neutral500)
                    .padding(.bottom, Spacing.m)
                
                OnboardingStepDimmedView(
                    title: T.onboardingProgressStep1Title.localizedKey,
                    subtitle: T.onboardingProgressStep1Description.localizedKey,
                    isChecked: true,
                    isTitleStrikethrough: true,
                    areTextsGreyedOut: true
                )
                .padding(.bottom, Spacing.s)
                
                OnboardingStepDimmedView(
                    title: T.onboardingProgressStep2Title.localizedKey,
                    subtitle: T.onboardingProgressStep2Description.localizedKey,
                    isSelected: finished == false,
                    isChecked: firstStepCompleted,
                    areTextsGreyedOut: finished
                )
            }
            .padding(Spacing.s)
            .overlay {
                RoundedRectangle(cornerRadius: Constants.FullFrame.cornerRadius)
                    .stroke(.neutral100, lineWidth: Constants.FullFrame.lineWidth)
            }
            .padding(.top, Spacing.xll3)
            .padding(.horizontal, Spacing.xl)
            
            Spacer()
            
            Button(T.onboardingProgressCompletedCta.localizedKey) {
                presenter.onFinish(using: dismissFlow)
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .opacity(finished ? 1 : 0)
            .animation(.easeInOut.delay(Constants.showContinueButtonDelay), value: finished)
            .padding(.bottom, Spacing.xl)
            .padding(.horizontal, Spacing.xl)
        }
        .sensoryFeedback(.selection, trigger: finishedFeedback)
        .onAppear {
            Task {
                try await Task.sleep(for: Constants.firstStepCompletedDelay)
                firstStepCompleted = true
                
                try await Task.sleep(for: Constants.finishedDelay)
                finished = true
                
                try await Task.sleep(for: Constants.finishedFeedbackDelay)
                finishedFeedback = true
            }
        }
        .onboardingStepTopPadding()
        .onboardingStepProgress(Constants.stepProgress)
        .readableContentMargins()
    }
}

#Preview {
    OnboardingStepsStack {
        SetupCompleteRouter.buildView()
    }
}
