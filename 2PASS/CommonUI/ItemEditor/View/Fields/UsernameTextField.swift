// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private enum Constants {
    static let inputAccessoryHeight: CGFloat = 44
    static let inputAccessoryHeightLiquidGlass: CGFloat = 64
}

struct UsernameTextField: UIViewRepresentable {
    @Binding var text: String

    let placeholder: LocalizedStringResource
    let mostUsedUsernames: [String]
    let onSelectUsername: (String) -> Void
    let onShowMoreTapped: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = String(localized: placeholder)
        textField.text = text
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true

        textField.textContentType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        textField.keyboardType = .asciiCapable
        textField.autocapitalizationType = .none
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []

        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        setupInputAccessoryView(for: textField, context: context)

        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }

        if textField.inputAccessoryView == nil && !mostUsedUsernames.isEmpty {
            setupInputAccessoryView(for: textField, context: context)

            if textField.isFirstResponder {
                textField.reloadInputViews()
            }
        }
    }

    private func setupInputAccessoryView(for textField: UITextField, context: Context) {
        guard !mostUsedUsernames.isEmpty else { return }

        let frame: CGRect
        if #available(iOS 26, *) {
            frame = CGRect(x: 0, y: 0, width: 0, height: Constants.inputAccessoryHeightLiquidGlass)
        } else {
            frame = CGRect(x: 0, y: 0, width: 0, height: Constants.inputAccessoryHeight)
        }

        let inputView = UIInputView(frame: frame, inputViewStyle: .keyboard)

        let buttons = mostUsedUsernames.map { username in
            var config: UIButton.Configuration
            if #available(iOS 26, *) {
                config = UIButton.Configuration.glass()
            } else {
                config = UIButton.Configuration.plain()
                config.baseForegroundColor = .label
            }

            config.titleAlignment = .center
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { container in
                var container = container
                container.font = UIFont.preferredFont(forTextStyle: .footnote)
                return container
            }

            let button = UIButton(configuration: config, primaryAction: UIAction(title: username) { [weak textField] _ in
                context.coordinator.parent.onSelectUsername(username)
                textField?.resignFirstResponder()
            })
            button.titleLabel?.textAlignment = .center
            button.setContentHuggingPriority(.defaultHigh + 1, for: .horizontal)
            return button
        }

        var showMoreConfig: UIButton.Configuration
        if #available(iOS 26, *) {
            showMoreConfig = UIButton.Configuration.glass()
        } else {
            showMoreConfig = UIButton.Configuration.plain()
            showMoreConfig.baseForegroundColor = .label
        }

        let showMoreButton = UIButton(configuration: showMoreConfig, primaryAction: UIAction(image: UIImage(systemName: "person.badge.key")) { _ in
            context.coordinator.parent.onShowMoreTapped()
        })
        showMoreButton.translatesAutoresizingMaskIntoConstraints = false
        inputView.addSubview(showMoreButton)

        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.setContentHuggingPriority(.defaultHigh + 1, for: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        inputView.addSubview(stackView)

        let isLiquidGlass: Bool
        if #available(iOS 26, *) {
            isLiquidGlass = true
            stackView.spacing = 8
        } else {
            isLiquidGlass = false
        }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: inputView.leadingAnchor, constant: isLiquidGlass ? 16 : 0),
            stackView.topAnchor.constraint(equalTo: inputView.topAnchor, constant: 5),
            stackView.bottomAnchor.constraint(equalTo: inputView.bottomAnchor, constant: isLiquidGlass ? -12 : 0),
            stackView.trailingAnchor.constraint(equalTo: showMoreButton.leadingAnchor, constant: isLiquidGlass ? -16 : 0),

            showMoreButton.trailingAnchor.constraint(equalTo: inputView.trailingAnchor, constant: isLiquidGlass ? -20 : -4),
            showMoreButton.topAnchor.constraint(equalTo: inputView.topAnchor, constant: 5),
            showMoreButton.bottomAnchor.constraint(equalTo: inputView.bottomAnchor, constant: isLiquidGlass ? -12 : 0),
            showMoreButton.widthAnchor.constraint(equalTo: showMoreButton.heightAnchor)
        ])

        textField.inputAccessoryView = inputView
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UsernameTextField

        init(_ parent: UsernameTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            Task { @MainActor in
                self.parent.text = textField.text ?? ""
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
