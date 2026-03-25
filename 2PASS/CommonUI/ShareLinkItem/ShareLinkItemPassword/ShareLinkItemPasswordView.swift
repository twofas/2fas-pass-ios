// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import SwiftUIIntrospect
import UIKit
import Common

struct ShareLinkItemPasswordView: View {

    @State var presenter: ShareLinkItemPasswordPresenter
    var onSave: (String) -> Void
    var onCancel: () -> Void

    private static let minimumLength: Int32 = 8
    private static let inputAccessoryHeight: CGFloat = 44
    private static let inputAccessoryHeightLiquidGlass: CGFloat = 64

    @State private var showMinLengthError = false

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

                            Spacer(minLength: 0)
                                .frame(maxHeight: 24)
                            
                            VStack(spacing: 8) {
                                Text(.shareLinkItemSetPasswordTitle)
                                    .font(.title1Emphasized)
                                    .foregroundStyle(.base1000)

                                Text(.shareLinkItemSetPasswordSubtitle)
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
                    if #available(iOS 26.0, *) {
                        Button {
                            onSave(presenter.password)
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    } else {
                        Button(String(localized: .commonSave)) {
                            onSave(presenter.password)
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .router(
                router: ShareLinkItemPasswordRouter(),
                destination: $presenter.destination
            )
            
        }
        .background(Color(UIColor(light: .systemGroupedBackground, dark: .black)), ignoresSafeAreaEdges: .all)
        .introspect(.navigationStack, on: .iOS(.v17, .v18, .v26)) { viewControler in
            viewControler.traitOverrides.userInterfaceLevel = .base
        }
    }

    // MARK: - Password Input

    @ViewBuilder
    private var passwordInput: some View {
        SharePasswordInput(text: $presenter.password)
            .errorMessage(
                showMinLengthError
                ? String(localized: .shareLinkItemPasswordMinLength(Self.minimumLength))
                : nil
            )
            .autoFocus()
            .introspect { textField in
                textField.returnKeyType = .done
                setupInputAccessoryView(textField)
            }
            .shouldReturn {
                if isValid {
                    return true
                } else {
                    showMinLengthError = true
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
                    presenter.onGeneratePasswordTapped()
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

private class ShareLinkItemPasswordPreviewInteractor: ShareLinkItemPasswordModuleInteracting {
    func generatePassword() -> String { "Pr3v!ewP@ss" }
}

#Preview {
    Color.backgroundPrimary
        .sheet(isPresented: .constant(true)) {
            ShareLinkItemPasswordView(
                presenter: .init(
                    initialPassword: "",
                    interactor: ShareLinkItemPasswordPreviewInteractor()
                ),
                onSave: { _ in },
                onCancel: {}
            )
        }
}
