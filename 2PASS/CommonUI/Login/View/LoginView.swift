// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let appLockInfoHeight = 28.0
    static let passwordInputCornerRadius = 10.0
    static let passwordInputHeight = 44.0
    static let appLockTooltipAnimationDuration = 0.2
}

public struct LoginView: View {
    
    private enum FocusedField {
        case login
    }
    
    @State
    var presenter: LoginPresenter
    
    @FocusState
    private var focusedField: FocusedField?
    
    @State
    private var showResetApp = false
    
    @State
    private var keyboardObserver = KeyboardObserver()
    
    @Environment(\.dismiss)
    private var dismiss
    
    @Namespace
    private var namespace
    
    private let logoId = "logoId"
    
    public init(presenter: LoginPresenter) {
        self.presenter = presenter
    }
    
    @ViewBuilder
    public var body: some View {
        VStack {
            if presenter.showSplashScreen {
                splashView
            } else {
                enterPasswordView
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .router(router: LoginRouter(), destination: $presenter.destination)
        .onAppear {
            presenter.onAppear()
        }
        .readableContentMargins()
        .navigationDestination(isPresented: $presenter.showMigrationFailed) {
            ResultView(kind: .failure, title: Text(.migrationErrorTitle)) {
                Button(.commonClose) {
                    presenter.onMigrationFailedClose()
                }
            }
        }
        .onAppear {
            if presenter.showKeyboard {
                focusedField = .login
            }
        }
        .onChange(of: presenter.showKeyboard) { _, newValue in
            if newValue {
                focusedField = .login
            } else {
                focusedField = nil
            }
        }
        .onChange(of: presenter.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
    }
    
    @ViewBuilder
    private var splashView: some View {
        Color.clear
            .overlay {
                Image(.smallShield)
                    .matchedGeometryEffect(id: logoId, in: namespace)
                    .transition(.identity)
                    .zIndex(1)
            }
            .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var enterPasswordView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Image(.smallShield)
                    .matchedGeometryEffect(id: logoId, in: namespace)
                    .transition(.identity)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xs)
                    .zIndex(1)
                
                VStack(spacing: 0) {
                    HeaderContentView(
                        title: Text(.lockScreenUnlockTitleIos),
                        subtitle: presenter.isAppLocked ? nil : welcomeText
                    )
                    
                    Spacer()
                        .frame(maxHeight: presenter.isAppLocked ? Spacing.s : 40)
                    
                    if let lockTimeRemaining = presenter.lockTimeRemaining {
                        lockTimeInfo(remaining: lockTimeRemaining)
                    }
                    
                    Section {
                        passwordInput
                    } footer: {
                        errorDescription
                    }
                    
                    if presenter.showBiometryButton {
                        biometryButton
                    }
                    
                    Spacer(minLength: Spacing.xs)
                    
                    VStack(spacing: Spacing.m) {
                        if presenter.isAppLocked {
                            Text(.lockScreenTooManyAttemptsDescription)
                                .font(.system(.caption))
                                .foregroundStyle(.neutral600)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(.lockScreenUnlockCta) {
                            focusedField = nil
                            presenter.onLogin()
                        }
                        .buttonStyle(.filled)
                        .controlSize(.large)
                        .disabled(!presenter.isUnlockAvailable)
                        
                        if presenter.hasAppReset {
                            SecondaryDestructiveButton(title: String(localized: .lockScreenResetApp)) {
                                showResetApp = true
                            }
                        }
                    }
                    .animation(.easeInOut(duration: Constants.appLockTooltipAnimationDuration), value: presenter.isAppLocked)
                }
                .disabled(presenter.screenDisabled)
                .opacity(presenter.isEnterPasswordVisible ? 1 : 0)
                .padding(.horizontal, Spacing.xl)
                .alert(String(localized: .lockScreenResetAppTitle), isPresented: $showResetApp) {
                    Button(role: .destructive) {
                        presenter.onAppReset()
                    } label: {
                        Text(.lockScreenResetApp)
                            .foregroundStyle(.destructiveAction)
                    }
                }
                .toolbar {
                    if presenter.showCancel {
                        ToolbarItem(placement: .cancellationAction) {
                            ToolbarCancelButton {
                                dismiss()
                            }
                        }
                    }
                }
            }
            .padding(.bottom, max(presenter.allowsForgotMasterPassword ? 0 : Spacing.m, keyboardObserver.keyboardHeight - proxy.safeAreaInsets.bottom + Spacing.m))
            .animation(.smooth(duration: 0.2), value: keyboardObserver.keyboardHeight)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                    }
            )
            .animation(.smooth, value: presenter.errorDescription.isEmpty)
        }
        .safeAreaInset(edge: .bottom, content: {
            if presenter.allowsForgotMasterPassword {
                Button(.lockScreenForgotMasterPasswordCta) {
                    presenter.onForgotMasterPassword()
                }
                .buttonStyle(.twofasBorderless)
                .controlSize(.large)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.m)
                .disabled(presenter.isAppLocked)
            }
        })
        .ignoresSafeArea(.keyboard)
    }
    
    @ViewBuilder
    private func lockTimeInfo(remaining: Duration) -> some View {
        let time = Text(remaining, format: .time(pattern: .minuteSecond))
            .bold()
            .monospacedDigit()
        
        Text("lock_screen_try_again \(time)")
            .padding(.horizontal, 10)
            .frame(height: Constants.appLockInfoHeight)
            .background(Color.neutral50)
            .clipShape(Capsule())
            .padding(.bottom, 50)
    }
    
    @ViewBuilder
    private var passwordInput: some View {
        SecureInput(label: .masterPasswordLabel, value: $presenter.loginInput)
            .onSubmit {
                presenter.onLogin()
            }
            .focused($focusedField, equals: .login)
            .submitLabel(.go)
            .padding(.leading, Spacing.l)
            .padding(.trailing, 11)
            .frame(height: Constants.passwordInputHeight)
            .background(Color.neutral50)
            .overlay {
                RoundedRectangle(cornerRadius: Constants.passwordInputCornerRadius)
                    .stroke(.danger500, lineWidth: presenter.inputError ? 1 : 0)
            }
            .sensoryFeedback(trigger: presenter.inputError, { oldValue, newValue in
                newValue ? .error : nil
            })
            .clipShape(RoundedRectangle(cornerRadius: Constants.passwordInputCornerRadius))
            .shakeAnimation(trigger: presenter.inputError)
    }
    
    @ViewBuilder
    private var errorDescription: some View {
        ZStack {
            if presenter.errorDescription.isEmpty == false {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.danger500)
                    
                    Text(presenter.errorDescription)
                        .font(.caption1Emphasized)
                        .foregroundStyle(.danger500)
                    
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)
            }
        }
        .animation(nil, value: presenter.errorDescription.isEmpty)
        .frame(minHeight: Spacing.xl)
    }
    
    @ViewBuilder
    private var biometryButton: some View {
        Button {
            focusedField = nil
            presenter.onBiometry()
        } label: {
            switch presenter.biometryType {
            case .faceID:
                Label(.lockScreenUnlockUseFaceid, systemImage: "faceid")
            case .touchID:
                Label(.lockScreenUnlockUseTouchid, systemImage: "touchid")
            case .missing:
                EmptyView()
            }
        }
        .buttonStyle(.bezeledGray(fillSpace: false))
        .controlSize(.small)
    }
    
    private var welcomeText: Text {
        switch presenter.loginType {
        case .login: Text(.lockScreenUnlockDescription)
        case .verify, .restore: Text(.lockScreenEnterMasterPassword)
        }
    }
}

#Preview {
    LoginView(presenter: .init(loginSuccessful: {}, interactor: ModuleInteractorFactory.shared.loginModuleInteractor(config: .init(allowBiometrics: false, loginType: .login))))
}
