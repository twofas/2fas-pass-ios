// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import SwiftUI

private struct Constants {
    static let appearAnimationDelay: Duration = .milliseconds(200)
    static let selectStepAnimationDelay: Duration = .milliseconds(1300)
    static let firstStepSelectedDelay: Duration = .milliseconds(1100)
    static let firstStepSelectedFeedbackDelay: Duration = .milliseconds(150)
    static let secondStepSelectedFeedbackDelay: Duration = .seconds(1)
    static let finishSelectedFeedbackDelay: Duration = .seconds(1)
    static let dimmedBorderDelay: Duration = .milliseconds(900)
    
    static let showContinueButtonAnimationDuration = 0.15
    static let showContinueButtonDelay = 1.2
    
    static let firstStepAppearDelay = 0.3
    static let secondStepAppearDelay = 0.6
    
    static let stepsTopPadding = 48.0
        
    struct SelectedStepFrame {
        static let cornerRadius = 16.0
        static let lineWidth: CGFloat = 2.0
    }
    
    static let moveSelectedFrameAnimationDuration = 0.4
    static let moveSelectedFrameAnimationDelay = 1.0
}


struct ConnectPermissionsView: View {
    
    @State
    var presenter: ConnectPermissionsPresenter
    
    @Environment(\.dismiss)
    private var dismiss
    
    @State private var appearAnimation = false
    @State private var dimmedBorder = false
    @State private var firstStepSelected = false
    @State private var firstStepSelectedFeedback = false
    @State private var secondStepSelectedFeedback = false
    @State private var finishSelectedFeedback = false
    
    @Namespace var namespace
    @State var visibleSelectedStep = false
    
    @Environment(\.openURL) private var openURL
    @Environment(\.dismissFlow) private var dismissFlow
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: presenter.progress)
                    .progressViewStyle(ShieldProgressStyle())
                    .animation(.default, value: presenter.progress)
                    .padding(.bottom, Spacing.xl)
                
                HeaderContentView(
                    title: Text(T.connectSetupHeader.localizedKey),
                    subtitle: Text(T.connectSetupDescription.localizedKey)
                )
                
                Spacer(minLength: Spacing.s)
                    .frame(maxHeight: Constants.stepsTopPadding)
                
                StepsContainerView(title: Text(T.connectSetupStepsHeader.localizedKey)) {
                    StepView(
                        title: Text(T.connectSetupCameraStepTitle.localizedKey),
                        subtitle: Text(T.connectSetupCameraStepDescription.localizedKey),
                        accessory: {
                            ConnectPermissionsStepAccessoryView(status: presenter.stepsStatus[.camera])
                        }
                    )
                    .completed(presenter.stepsStatus[.camera] == .success)
                    .stepAppearAnimation(appearAnimation, delay: Constants.firstStepAppearDelay)
                    .matchedGeometryEffect(id: ConnectPermissionsPresenter.Step.camera, in: namespace)
                    
                    StepView(
                        title: Text(T.connectSetupPushStepTitle.localizedKey),
                        subtitle: Text(T.connectSetupPushStepDescription.localizedKey),
                        accessory: {
                            ConnectPermissionsStepAccessoryView(status: presenter.stepsStatus[.pushNotifications])
                        }
                    )
                    .completed(presenter.stepsStatus[.pushNotifications] == .success)
                    .stepAppearAnimation(appearAnimation, delay: Constants.secondStepAppearDelay)
                    .matchedGeometryEffect(id: ConnectPermissionsPresenter.Step.pushNotifications, in: namespace)
                }
                .appearAnimationTrigger(presenter.stepsStatus[.camera] == nil ? appearAnimation : true)
                .sensoryFeedback(.selection, trigger: firstStepSelectedFeedback)
                .sensoryFeedback(.selection, trigger: secondStepSelectedFeedback)
                .sensoryFeedback(.selection, trigger: finishSelectedFeedback)
                .overlay {
                    RoundedRectangle(cornerRadius: Constants.SelectedStepFrame.cornerRadius)
                        .stroke(.brand300, lineWidth: Constants.SelectedStepFrame.lineWidth)
                        .matchedGeometryEffect(id: presenter.currentStep, in: namespace, isSource: false)
                        .opacity(visibleSelectedStep ? 1 : 0)
                        .animation(.easeInOut, value: visibleSelectedStep)
                        .animation(.smooth(duration: Constants.moveSelectedFrameAnimationDuration).delay(Constants.moveSelectedFrameAnimationDelay), value: presenter.currentStep)
                }
                .padding(.horizontal, Spacing.xl)
                .onAppear {
                    Task {
                        try await Task.sleep(for: Constants.selectStepAnimationDelay)
                        
                        if presenter.isFinished == false {
                            visibleSelectedStep = true
                        }
                    }
                }
                .onChange(of: presenter.currentStep, { _, newValue in
                    if newValue == .pushNotifications {
                        Task {
                            try await Task.sleep(for: Constants.secondStepSelectedFeedbackDelay)
                            secondStepSelectedFeedback = true
                        }
                    }
                })
                .onChange(of: presenter.isFinished, { _, newValue in
                    if newValue {
                        visibleSelectedStep = false
                        
                        Task {
                            try await Task.sleep(for: Constants.finishSelectedFeedbackDelay)
                            finishSelectedFeedback = true
                        }
                    }
                })
                
                Spacer(minLength: Spacing.s)
                
                ZStack {
                    if presenter.isFinished {
                        VStack(spacing: Spacing.m) {
                            if presenter.stepsStatus[.pushNotifications] == .warning {
                                Text(AttributedString(localized: "connect_setup_push_warning_ios \(UIApplication.openNotificationSettingsURLString)"))
                                    .font(.caption)
                                    .foregroundStyle(.neutral600)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(T.connectSetupFinishCta.localizedKey) {
                                presenter.finishOnboarding()
                                dismissFlow()
                            }
                        }
                        .padding(.horizontal, Spacing.xl)
                    } else if presenter.stepsStatus[.camera] == .failed {
                        SettingsSystemLinkButton(description: Text(T.connectSetupCameraError.localizedKey)) {
                            if let url = presenter.appSettingsURL {
                                openURL(url)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Button(presenter.currentStep == .camera ? T.connectSetupCameraCta.localizedKey : T.connectSetupPushCta.localizedKey) {
                            if presenter.shouldDismiss {
                                presenter.finishOnboarding()
                                dismissFlow()
                            } else {
                                presenter.onContinue()
                            }
                        }
                        .padding(.horizontal, Spacing.xl)
                    }
                }
                .padding(.bottom, Spacing.l)
                .buttonStyle(.filled)
                .controlSize(.large)
                .opacity(appearAnimation ? 1 : 0)
                .opacity(presenter.isWaitingForUser ? 0 : 1)
                .animation(.easeInOut(duration: Constants.showContinueButtonAnimationDuration).delay(Constants.showContinueButtonDelay), value: appearAnimation)
                .animation(presenter.isWaitingForUser ? .easeInOut(duration: Constants.showContinueButtonAnimationDuration) : .easeInOut(duration: Constants.showContinueButtonAnimationDuration).delay(Constants.showContinueButtonDelay), value: presenter.isWaitingForUser)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T.commonClose.localizedKey) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if presenter.stepsStatus[.camera] == nil {
                    Task {
                        try await Task.sleep(for: Constants.appearAnimationDelay)
                        appearAnimation = true
                        
                        try await Task.sleep(for: Constants.firstStepSelectedDelay)
                        firstStepSelected = true
                        
                        try await Task.sleep(for: Constants.firstStepSelectedFeedbackDelay)
                        firstStepSelectedFeedback = true
                    }
                    
                    Task {
                        try await Task.sleep(for: Constants.dimmedBorderDelay)
                        dimmedBorder = true
                    }
                } else {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        appearAnimation = true
                        firstStepSelected = true
                        dimmedBorder = true
                        visibleSelectedStep = true
                    }
                }
            }
            .background(.base0)
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    @State @Previewable var showSheet: Bool = true
    
    Button("Show") {
        showSheet = true
    }
    .sheet(isPresented: $showSheet) {
        ConnectPermissionsView(presenter: .init(interactor: ModuleInteractorFactory.shared.connectPermissionsModuleInteractor()))
    }
}
