// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Lottie
import CommonUI

private struct Constants {
    enum Lottie {
        enum SecretKey {
            static let size: CGFloat = 298
            static let borderSize: CGFloat = 220
            static let borderWidth: CGFloat = 5
        }
        
        enum TickSuccess {
            static let size: CGFloat = 40
            static let borderSize: CGFloat = 80
            static let borderWidth: CGFloat = 2
        }
    }
    
    enum Button {
        static let cornerRadius: CGFloat = 10
        static let height: CGFloat = 50
        static let tapScale: CGFloat = 0.96
        static let tapScaleLiquidGlass: CGFloat = 0.92
        static let tapOpacity: CGFloat = 0.9
    }
    
    enum Animation {
        static let generateDuration: TimeInterval = 1
        static let cancelDuration: TimeInterval = 0.4
        static let waitingSpeed = 0.5
        static let generatingSpeed = 2.0
        static let finalProgressScale = 1.1
        static let finishDuration = 0.3
        static let tapScaleDuration = 0.2
    }
    
    enum StepProgress {
        static let start: Float = 0.2
        static let end: Float = 0.4
    }
}

struct GenerateSecretKeyView: View {

    @State
    var presenter: GenerateSecretKeyPresenter

    @State
    private var generateSecretKeyAnimator = InteractiveProgressAnimator(
        animationDuration: Constants.Animation.generateDuration,
        cancelAnimationDuration: Constants.Animation.cancelDuration
    )
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if presenter.isFinished {
                    HeaderContentView(
                        title: Text(T.onboardingGenerateSecretKeySuccessTitle.localizedKey),
                        subtitle: Text(T.onboardingGenerateSecretKeySuccessDescription.localizedKey)
                    )
                    .readableContentMargins()
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .trailing))
                } else {
                    HeaderContentView(
                        title: Text(T.onboardingGenerateSecretKeyTitle.localizedKey),
                        subtitle: Text(T.onboardingGenerateSecretKeyDescription.localizedKey)
                    )
                    .readableContentMargins()
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .leading))
                }
            }
            .animation(.default, value: presenter.isFinished)
            
            Spacer(minLength: 0)
            
            ZStack {
                ZStack {
                    if presenter.isFinished {
                        LottieSchemedAnimationView(baseNamed: "ios-tick") { lottieView in
                            lottieView
                                .playing()
                                .frame(width: Constants.Lottie.TickSuccess.size)
                        }
                    } else {
                        LottieView(animation: .named("ios-secret-key"))
                            .animationSpeed(generateSecretKeyAnimator.isFinished ? 0 : generateSecretKeyAnimator.isGenerating ? Constants.Animation.generatingSpeed : Constants.Animation.waitingSpeed)
                            .looping()
                    }
                }
                .frame(width: Constants.Lottie.SecretKey.size, height: Constants.Lottie.SecretKey.size)
                
                lottieBorders()
            }
            .scaleEffect(1 + (Constants.Animation.finalProgressScale - 1) * generateSecretKeyAnimator.progress)
            .padding(.bottom, 30)
            .sensoryFeedback(.success, trigger: presenter.isFinished)
            
            Spacer(minLength: 0)

            bottomButton()
                .padding(.bottom, Spacing.xl)
        }
        .onAppear { presenter.onAppear() }
        .onChange(of: generateSecretKeyAnimator.isFinished) { _, newValue in
            if newValue {
                presenter.onFinishGenerating()
            }
        }
        .router(router: GenerateSecretKeyRouter(), destination: $presenter.destination)
        .onboardingStepTopPadding()
        .onboardingStepProgress(presenter.isFinished ? Constants.StepProgress.end : Constants.StepProgress.start)
    }
    
    private func lottieBorders() -> some View {
        ZStack {
            Circle()
                .stroke(.neutral50, lineWidth: Constants.Lottie.SecretKey.borderWidth)
                .opacity(presenter.isFinished ? 0 : 1)
                .animation(nil, value: presenter.isFinished)
            
            Circle()
                .trim(from: 0, to: generateSecretKeyAnimator.progress)
                .stroke(.brand500, style: .init(
                    lineWidth: presenter.isFinished ? Constants.Lottie.TickSuccess.borderWidth : Constants.Lottie.SecretKey.borderWidth,
                    lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(
            width: presenter.isFinished ? Constants.Lottie.TickSuccess.borderSize : Constants.Lottie.SecretKey.borderSize,
            height: presenter.isFinished ? Constants.Lottie.TickSuccess.borderSize : Constants.Lottie.SecretKey.borderSize
        )
        .animation(.smooth(duration: Constants.Animation.finishDuration), value: presenter.isFinished)
    }
    
    @ViewBuilder
    private func bottomButton() -> some View {
        ZStack {
            if presenter.isFinished {
                Button(T.commonContinue.localizedKey) {
                    presenter.onContinueTap()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
                .padding(.horizontal, Spacing.xl)
                .readableContentMargins()
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing))
            } else {
                tapAndHoldLongPressView
                    .padding(.horizontal, Spacing.xl)
                    .readableContentMargins()
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.default, value: presenter.isFinished)
    }
    
    @ViewBuilder
    private var tapAndHoldLongPressView: some View {
        Text(T.onboardingGenerateSecretKeyCta.localizedKey)
            .frame(height: Constants.Button.height)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.baseStatic0)
            .background {
                tapAndHoldLongPressShape
                    .opacity(generateSecretKeyAnimator.isGenerating ? Constants.Button.tapOpacity : 1)
            }
            .onLongPressGesture(
                minimumDuration: .infinity,
                perform: {},
                onPressingChanged: { status in
                    generateSecretKeyAnimator.onPressingChanged(to: status)
                }
            )
            .sensoryFeedback(.selection, trigger: generateSecretKeyAnimator.isGenerating)
            .disabled(presenter.isFinished)
            .modify {
                if #available(iOS 26, *) {
                    $0.glassEffect(.regular.interactive())
                        .scaleEffect(generateSecretKeyAnimator.isGenerating ? Constants.Button.tapScaleLiquidGlass : 1)
                } else {
                    $0.scaleEffect(generateSecretKeyAnimator.isGenerating ? Constants.Button.tapScale : 1)
                }
            }
            .animation(.smooth(duration: Constants.Animation.tapScaleDuration), value: generateSecretKeyAnimator.isGenerating)
    }
    
    @ViewBuilder
    private var tapAndHoldLongPressShape: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(.brand500)
        } else {
            RoundedRectangle(cornerRadius: Constants.Button.cornerRadius)
                .fill(.brand500)
        }
    }
}

#Preview {
    OnboardingStepsStack {
        GenerateSecretKeyRouter.buildView()
    }
}
