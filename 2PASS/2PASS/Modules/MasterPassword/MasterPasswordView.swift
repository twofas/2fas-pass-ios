// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let contentTopPaddingForHideProgress = 44.0 + 16.0
    
    static let stepProgressVisibilityAnimationDuration = 0.3
    
    static let focusInputDelay: Duration = .milliseconds(600)
    static let focusRetypeInputDelay: Duration = .milliseconds(270)
    
    static let inputHeight: CGFloat = 60
    static let inputsCornerRadius: CGFloat = 12
    static let inputsTopPadding: CGFloat = 48
    static let inputsSeparatorHeight = 1.0
    
    static let stateInfoHeight = 44.0
    
    static let stepProgess: Float = 0.6
    
    static let headerIconTopPadding: CGFloat = 24
    static let headerIcomVisibilityAnimationDuration = 0.3
    static let headerIconOpacityAnimationDuration: Double = 0.1
    static let headerTopPadding: CGFloat = headerIconTopPadding + 66 /* header icon height */ + Spacing.xll
    static let headerTopPaddingFocuedField: CGFloat = 16
}

struct MasterPasswordView: View {
    
    private enum FocusedField {
        case first
        case second
    }
    
    @State
    var presenter: MasterPasswordPresenter
    
    @State
    private var fieldWidth: CGFloat?
    
    @FocusState
    private var focusedField: FocusedField?
    
    @State private var keyboard = KeyboardObserver()
    @State private var scrollPosition: String?
    
    var body: some View {
        switch presenter.kind {
        case .onboarding:
            content
                .onboardingStepProgressVisibility(focusedField == nil)
                .onboardingStepTopPadding { prefered in
                    onboardingTopPadding(prefered: prefered)
                }
                .animation(.smooth(duration: Constants.stepProgressVisibilityAnimationDuration), value: focusedField == nil)
                .onboardingStepProgress(Constants.stepProgess)
        default:
            content
                .padding(.top, settingsTopPadding)
                .overlay(alignment: .top) {
                    if presenter.kind != .onboarding {
                        Image(.smallShield)
                            .opacity(focusedField == nil ? 1 : 0)
                            .padding(.top, Constants.headerIconTopPadding)
                            .animation(.easeInOut(duration: Constants.headerIconOpacityAnimationDuration), value: focusedField == nil)
                    }
                }
                .animation(.smooth(duration: Constants.headerIcomVisibilityAnimationDuration), value: focusedField == nil)
        }
    }
    
    private var content: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                ScrollView {
                    header
                        .padding(.bottom, Constants.inputsTopPadding)
                    
                    VStack(spacing: 0) {
                        HStack {
                            FloatingField(placeholder: Text(.masterPasswordLabel), isEmpty: presenter.firstInput.isEmpty) {
                                SecureContentInput(
                                    label: "",
                                    value: $presenter.firstInput,
                                    isReveal: presenter.firstInputReveal
                                )
                            }
                            .focused($focusedField, equals: .first)
                            .onSubmit {
                                focusSecondField()
                                scrollToInfoState(in: scrollProxy)
                            }
                            
                            Spacer()
                            
                            Toggle(isOn: $presenter.firstInputReveal, label: {})
                                .toggleStyle(RevealToggleStyle())
                        }
                        .frame(height: Constants.inputHeight)
                        .zIndex(1)
                        .background(.neutral50)
                        
                        Color.neutral200
                            .frame(height: Constants.inputsSeparatorHeight)
                            .opacity(presenter.isRetype ? 1 : 0)
                        
                        if presenter.isRetype {
                            HStack {
                                FloatingField(placeholder: Text(.masterPasswordConfirmLabel), isEmpty: presenter.secondInput.isEmpty) {
                                    SecureContentInput(
                                        label: "",
                                        value: $presenter.secondInput,
                                        isReveal: presenter.secondInputReveal
                                    )
                                    .focused($focusedField, equals: .second)
                                    .onSubmit {
                                        presenter.onSavePassword()
                                    }
                                }
                                
                                Spacer()
                                
                                Toggle(isOn: $presenter.secondInputReveal, label: {})
                                    .toggleStyle(RevealToggleStyle())
                            }
                            .background(.neutral50)
                            .frame(height: Constants.inputHeight)
                            .transition(.offset(y: -Constants.inputHeight))
                        }
                    }
                    .animation(.default, value: presenter.isRetype)
                    .padding(.horizontal, Spacing.l)
                    .background(.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.inputsCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Constants.inputsCornerRadius)
                            .stroke(.danger500, lineWidth: presenter.showError ? 1 : 0)
                    }
                    .sensoryFeedback(trigger: presenter.showError, { oldValue, newValue in
                        newValue ? .error : nil
                    })
                    .padding(.horizontal, Spacing.xll)
                    .shakeAnimation(trigger: presenter.showError)
                    
                    stateInfo()
                        .padding(.top, Spacing.s)
                        .padding(.horizontal, Spacing.xll)
                        .id("info-state")
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: presenter.showError) { _, newValue in
                    if newValue {
                        scrollToInfoState(in: scrollProxy)
                    }
                }
                
                Button(.commonContinue) {
                    if presenter.isRetype == false {
                        focusSecondField()
                        scrollToInfoState(in: scrollProxy)
                    } else if presenter.currentState == .ok {
                        focusedField = nil
                    }
                    
                    presenter.onSavePassword()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
                .frame(alignment: .bottom)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
                .padding(.top, Spacing.s)
                .disabled(!presenter.isSaveEnabled)
            }
        }
        .task {
            do {
                try await Task.sleep(for: Constants.focusInputDelay)
                focusedField = .first
            } catch {}
        }
        .router(router: MasterPasswordRouter(), destination: $presenter.destination)
        .background(Color(.mainBackground))
        .readableContentMargins()
    }
    
    @ViewBuilder
    private var header: some View {
        switch presenter.kind {
        case .onboarding:
            HeaderContentView(
                title: Text(.onboardingCreateMasterPasswordTitle),
                subtitle: Text(.onboardingCreateMasterPasswordDescription)
            )
        case .change:
            HeaderContentView(
                title: Text(.setNewPasswordScreenTitle),
                subtitle: Text(.setNewPasswordScreenDescription)
            )
        case .unencryptedVaultRecovery:
            HeaderContentView(
                title: Text(.onboardingCreateMasterPasswordTitle),
                subtitle: Text(.onboardingCreateMasterPasswordDescription)
            )
        }
    }
    
    private func focusSecondField() {
        Task {
            try await Task.sleep(for: Constants.focusRetypeInputDelay)
            focusedField = .second
        }
    }
    
    private func scrollToInfoState(in proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("info-state")
        }
    }
    
    @ViewBuilder
    private func stateInfo() -> some View {
        HStack {
            switch presenter.currentState {
            case .empty, .ok:
                EmptyView()
            case .tooShort:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.descriptionText)
                Text(.masterPasswordMinLength(Int32(presenter.optimalLength)))
                    .font(.caption)
            case .dontMatch:
                if presenter.showError {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.danger600)
                    Text(.masterPasswordNotMatch)
                        .font(.caption)
                        .foregroundStyle(.danger600)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: Constants.stateInfoHeight, alignment: .top)
    }
    
    private func onboardingTopPadding(prefered: CGFloat) -> CGFloat {
        if focusedField == nil {
            return prefered
        } else {
            return Constants.contentTopPaddingForHideProgress
        }
    }
    
    private var settingsTopPadding: CGFloat {
        if focusedField == nil {
            return Constants.headerTopPadding
        } else {
            return Constants.headerTopPaddingFocuedField
        }
    }
}

#Preview {
    OnboardingStepsStack {
        MasterPasswordRouter.buildView(kind: .onboarding, onFinish: {}, onClose: {})
    }
}

#Preview {
    NavigationStack {
        MasterPasswordRouter.buildView(kind: .change, onFinish: {}, onClose: {})
    }
}
