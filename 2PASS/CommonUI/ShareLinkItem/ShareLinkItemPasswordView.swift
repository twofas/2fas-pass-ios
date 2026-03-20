// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit
import Common

struct ShareLinkItemPasswordView: View {

    @State var presenter: ShareLinkItemPasswordPresenter
    var onSave: (String) -> Void
    var onCancel: () -> Void

    private static let minimumLength = 8
    private static let inputAccessoryHeight: CGFloat = 44
    private static let inputAccessoryHeightLiquidGlass: CGFloat = 64

    @State private var didFocus = false
    @State private var showMinLengthError = false
    @State private var errorShakeTrigger = 0

    private var isValid: Bool {
        presenter.password.isEmpty || presenter.password.count >= Self.minimumLength
    }

    private var canSave: Bool {
        isValid && !(presenter.initialPassword.isEmpty && presenter.password.isEmpty)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                ZStack(alignment: .top) {
                    Image(.shareLinkTop)
                        .resizable()
                        .frame(height: 159)
                        .ignoresSafeArea()

                    VStack {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                                .frame(maxHeight: 32)
                            
                            Image(.shareStar)
//                                .padding(.top, 32)

                            Spacer(minLength: 0)
                                .frame(maxHeight: 24)
                            
                            VStack(spacing: 8) {
                                Text("Set link password")
                                    .font(.title1Emphasized)
                                    .foregroundStyle(.base1000)

                                Text("Secure your 2FAS Share link")
                                    .font(.subheadline)
                                    .foregroundStyle(.neutral950)
                            }
                            
                            Spacer(minLength: 0)
                                .frame(maxHeight: 24)

                            passwordInput
                                .padding(.top, 8)
                                .padding(.horizontal, Spacing.xl)
                        }

                        Spacer()
                    }
                }
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.frame(in: .global).minY) { oldY, newY in
                            if newY > oldY {
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            }
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(presenter.password)
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
            }
        }
        .background(Color(.systemGroupedBackground), ignoresSafeAreaEdges: .all)
    }

    // MARK: - Password Input

    @ViewBuilder
    private var passwordInput: some View {
        VStack {
            SecureInput(label: .masterPasswordLabel, value: $presenter.password)
                .introspect { textField in
                    textField.returnKeyType = .done
                    setupInputAccessoryView(textField)

                    guard !didFocus else { return }
                    didFocus = true
                    textField.becomeFirstResponder()
                    DispatchQueue.main.async {
                        if let end = textField.position(from: textField.endOfDocument, offset: 0) {
                            textField.selectedTextRange = textField.textRange(from: end, to: end)
                        }
                    }
                }
                .shouldReturn {
                    if isValid {
                        return true
                    } else {
                        showMinLengthError = true
                        errorShakeTrigger += 1
                        return false
                    }
                }
                .onSubmit {
                    onSave(presenter.password)
                }
                .onChange(of: presenter.password) {
                    if showMinLengthError, isValid {
                        showMinLengthError = false
                    }
                }
                .padding(.leading, Spacing.l)
                .padding(.trailing, 4)
                .frame(height: 44.0)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 10.0)
                        .stroke(.danger500, lineWidth: showMinLengthError ? 1 : 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10.0))
                .sensoryFeedback(.error, trigger: errorShakeTrigger)
                .shakeAnimation(trigger: errorShakeTrigger)

            if showMinLengthError {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.danger500)
                    Text("Password must be at least \(Self.minimumLength) characters")
                        .font(.caption1Emphasized)
                        .foregroundStyle(.danger500)
                    Spacer()
                }
                .padding(.horizontal, Spacing.m)
            }
        }
        .sheet(isPresented: $presenter.showGeneratePassword) {
            PasswordGeneratorRouter.buildView(close: {
                presenter.showGeneratePassword = false
            }) { generatedPassword in
                presenter.password = generatedPassword
                presenter.showGeneratePassword = false
            }
        }
    }

    // MARK: - Input Accessory View

    private func setupInputAccessoryView(_ textField: UITextField) {
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []

        guard textField.inputAccessoryView == nil else { return }

        let frame: CGRect
        if #available(iOS 26.0, *) {
            frame = CGRect(x: 0, y: 0, width: 0, height: Self.inputAccessoryHeightLiquidGlass)
        } else {
            frame = CGRect(x: 0, y: 0, width: 0, height: Self.inputAccessoryHeight)
        }

        let inputView = UIInputView(frame: frame, inputViewStyle: .keyboard)

        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = UIButton.Configuration.glass()
        } else {
            config = UIButton.Configuration.plain()
            config.baseForegroundColor = .label
        }

        config.imagePadding = 8

        let feedback = UIImpactFeedbackGenerator()
        let presenter = self.presenter

        let generateIconName: String = {
            if #available(iOS 18.0, *) {
                return "gearshape.arrow.trianglehead.2.clockwise.rotate.90"
            } else {
                return "gearshape.arrow.triangle.2.circlepath"
            }
        }()

        let stackView = UIStackView(arrangedSubviews: [
            UIButton(configuration: config, primaryAction: UIAction(
                title: String(localized: .loginPasswordGeneratorCta),
                image: UIImage(systemName: generateIconName),
                handler: { _ in
                    presenter.showGeneratePassword = true
                }
            )),
            UIButton(configuration: config, primaryAction: UIAction(
                title: String(localized: .loginPasswordAutogenerateCta),
                image: UIImage(systemName: "arrow.clockwise"),
                handler: { [weak textField] _ in
                    presenter.randomPassword()
                    feedback.impactOccurred(intensity: 0.5)
                    DispatchQueue.main.async {
                        guard let textField else { return }
                        if let end = textField.position(from: textField.endOfDocument, offset: 0) {
                            textField.selectedTextRange = textField.textRange(from: end, to: end)
                        }
                    }
                }
            )),
        ])

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        
        inputView.addSubview(stackView)

        if #available(iOS 26.0, *) {
            stackView.spacing = 16
            stackView.pinToParent(with: .init(top: 5, left: 16, bottom: 12, right: 16))
        } else {
            stackView.pinToParent(with: .init(top: 5, left: 0, bottom: 0, right: 0))
        }

        textField.inputAccessoryView = inputView
    }
}

#Preview {
    Color.backgroundPrimary
        .sheet(isPresented: .constant(true)) {
            ShareLinkItemPasswordView(
                presenter: .init(
                    initialPassword: "",
                    interactor: ShareLinkItemPreviewInteractor()
                ),
                onSave: { _ in },
                onCancel: {}
            )
        }
}
